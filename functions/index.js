require("dotenv").config();

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { GoogleGenAI } = require("@google/genai");
const admin = require("firebase-admin");
const { setGlobalOptions } = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");

admin.initializeApp();

const ai = new GoogleGenAI({
  apiKey: process.env.GEMINI_API_KEY,
});

const db = admin.firestore();

setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1",
});

/**
 * Yardımcı: sohbetin bekleyen admin cevap durumunu mesajlara göre senkronla
 */
async function syncChatPendingState(userId) {
  const pendingSnap = await db
    .collection("chats")
    .doc(userId)
    .collection("messages")
    .where("senderType", "==", "user")
    .where("needsAdminReply", "==", true)
    .where("isAnswered", "==", false)
    .limit(500)
    .get();

  const pendingCount = pendingSnap.size;
  const now = admin.firestore.FieldValue.serverTimestamp();

  await db.collection("chats").doc(userId).set(
    {
      userId,
      hasPendingAdminReply: pendingCount > 0,
      pendingAdminCount: pendingCount,
      updatedAt: now,
      ...(pendingCount > 0
        ? { pendingAdminSince: now }
        : { pendingAdminResolvedAt: now }),
    },
    { merge: true }
  );
}

/**
 * Yardımcı: belirli kullanıcı mesajını admin cevabı bekliyor olarak işaretle
 */
async function markMessageAsNeedsAdminReply({
  userId,
  messageId,
  question,
  score = 0,
}) {
  if (!userId || !messageId) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
  const msgRef = db
    .collection("chats")
    .doc(userId)
    .collection("messages")
    .doc(messageId);

  await msgRef.set(
    {
      needsAdminReply: true,
      isAnswered: false,
      escalated: true,
      escalatedAt: now,
      relatedQuestion: question || "",
      score: Number(score || 0),
      updatedAt: now,
    },
    { merge: true }
  );

  await syncChatPendingState(userId);
}

/**
 * Yardımcı: belirli mesaj için admin alert oluştur / güncelle
 */
async function createOrUpdateAdminAlert({
  userId,
  question,
  score = 0,
  sourceMessageId = "",
}) {
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (sourceMessageId) {
    const alertRef = db.collection("admin_alerts").doc(`${userId}_${sourceMessageId}`);
    const existing = await alertRef.get();

    await alertRef.set(
      {
        userId,
        question,
        score: Number(score || 0),
        sourceMessageId,
        status: "open",
        createdAt: existing.exists ? existing.data()?.createdAt || now : now,
        updatedAt: now,
      },
      { merge: true }
    );

    return;
  }

  const existingAlert = await db
    .collection("admin_alerts")
    .where("userId", "==", userId)
    .where("status", "==", "open")
    .limit(1)
    .get();

  if (existingAlert.empty) {
    await db.collection("admin_alerts").add({
      userId,
      question,
      score: Number(score || 0),
      sourceMessageId: "",
      status: "open",
      createdAt: now,
      updatedAt: now,
    });
  }
}

/**
 * 1) Template eklenince: mevcut kullanıcılar için sendQueue üret
 */
exports.onCreateNotificationTemplate = onDocumentCreated(
  "notifications/{templateId}",
  async (event) => {
    const templateId = event.params.templateId;
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const targetRole = String(data.targetRole || "");
    const title = String(data.title || "");
    const body = String(data.body || "");
    const delayDays = Number(data.delayDays || 0);
    const isActive = data.isActive === true;

    if (!isActive || !targetRole || !title) return;

    const usersSnap = await db
      .collection("users")
      .where("role", "==", targetRole)
      .get();

    if (usersSnap.empty) return;

    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();

    for (const uDoc of usersSnap.docs) {
      const u = uDoc.data() || {};
      const createdAt = u.createdAt;
      const token = u.fcmToken;

      if (!createdAt || typeof createdAt.toDate !== "function") continue;
      if (!token) continue;

      const dueDate = new Date(
        createdAt.toDate().getTime() + delayDays * 86400000
      );
      const dueAt = admin.firestore.Timestamp.fromDate(dueDate);

      const qRef = db.collection("sendQueue").doc(`${uDoc.id}_${templateId}`);
      batch.set(
        qRef,
        {
          uid: uDoc.id,
          token,
          role: targetRole,
          templateId,
          title,
          body,
          dueAt,
          sent: false,
          createdAt: now,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }
);

/**
 * 2) Yeni kullanıcı oluşunca: aktif template’lerden sendQueue üret
 */
exports.onCreateUserEnqueueTemplates = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const snap = event.data;
    if (!snap) return;

    const user = snap.data() || {};
    const role = String(user.role || "");
    const createdAt = user.createdAt;
    const token = user.fcmToken;

    if (!role) return;
    if (!createdAt || typeof createdAt.toDate !== "function") return;
    if (!token) return;

    await enqueueActiveTemplatesForUser({ uid, role, createdAt, token });
  }
);

/**
 * 3) Token sonradan gelirse veya değişirse
 */
exports.onUserTokenUpdatedEnqueueTemplates = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;

    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeToken = before.fcmToken || null;
    const afterToken = after.fcmToken || null;

    if (beforeToken === afterToken) return;

    const role = String(after.role || "");
    const createdAt = after.createdAt;

    if (!role) return;
    if (!createdAt || typeof createdAt.toDate !== "function") return;
    if (!afterToken) return;

    await enqueueActiveTemplatesForUser({
      uid,
      role,
      createdAt,
      token: afterToken,
    });

    const qSnap = await db
      .collection("sendQueue")
      .where("uid", "==", uid)
      .where("sent", "==", false)
      .limit(500)
      .get();

    if (!qSnap.empty) {
      const batch = db.batch();
      qSnap.docs.forEach((doc) => {
        batch.update(doc.ref, { token: afterToken });
      });
      await batch.commit();
    }
  }
);

async function enqueueActiveTemplatesForUser({ uid, role, createdAt, token }) {
  const templatesSnap = await db
    .collection("notifications")
    .where("targetRole", "==", role)
    .where("isActive", "==", true)
    .get();

  if (templatesSnap.empty) return;

  const batch = db.batch();
  const now = admin.firestore.Timestamp.now();

  for (const tDoc of templatesSnap.docs) {
    const t = tDoc.data() || {};
    const templateId = tDoc.id;

    const title = String(t.title || "");
    const body = String(t.body || "");
    const delayDays = Number(t.delayDays || 0);

    if (!title) continue;

    const dueDate = new Date(
      createdAt.toDate().getTime() + delayDays * 86400000
    );
    const dueAt = admin.firestore.Timestamp.fromDate(dueDate);

    const qRef = db.collection("sendQueue").doc(`${uid}_${templateId}`);
    batch.set(
      qRef,
      {
        uid,
        token,
        role,
        templateId,
        title,
        body,
        dueAt,
        sent: false,
        createdAt: now,
      },
      { merge: true }
    );
  }

  await batch.commit();
}

/**
 * 4) Scheduler: zamanı gelenleri gönder
 */
exports.sendDueNotifications = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "Europe/Istanbul",
    region: "europe-west1",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const dueSnap = await db
      .collection("sendQueue")
      .where("sent", "==", false)
      .where("dueAt", "<=", now)
      .limit(200)
      .get();

    if (dueSnap.empty) return;

    const batch = db.batch();

    for (const doc of dueSnap.docs) {
      const q = doc.data() || {};
      const token = q.token;

      if (!token) {
        batch.update(doc.ref, {
          sent: true,
          sentAt: now,
          error: "NO_TOKEN",
        });
        continue;
      }

      try {
        await admin.messaging().send({
          token,
          notification: {
            title: String(q.title || "Bildirim"),
            body: String(q.body || ""),
          },
          android: {
            priority: "high",
          },
          apns: {
            headers: {
              "apns-priority": "10",
            },
          },
          data: {
            templateId: String(q.templateId || ""),
            uid: String(q.uid || ""),
            role: String(q.role || ""),
          },
        });

        batch.update(doc.ref, {
          sent: true,
          sentAt: now,
        });
      } catch (e) {
        batch.update(doc.ref, {
          sent: true,
          sentAt: now,
          error: String(e?.message || e),
        });
      }
    }

    await batch.commit();
  }
);

/**
 * 5) Template güncellenince queue kayıtlarını güncelle
 */
exports.onUpdateNotificationTemplate = onDocumentUpdated(
  "notifications/{templateId}",
  async (event) => {
    const templateId = event.params.templateId;

    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const keys = ["targetRole", "title", "body", "delayDays", "isActive"];
    const changed = keys.some(
      (k) => JSON.stringify(before[k]) !== JSON.stringify(after[k])
    );
    if (!changed) return;

    const targetRole = String(after.targetRole || "");
    const title = String(after.title || "");
    const body = String(after.body || "");
    const delayDays = Number(after.delayDays || 0);
    const isActive = after.isActive === true;

    if (!isActive) {
      const qSnap = await db
        .collection("sendQueue")
        .where("templateId", "==", templateId)
        .where("sent", "==", false)
        .limit(500)
        .get();

      if (qSnap.empty) return;

      const batch = db.batch();
      const now = admin.firestore.Timestamp.now();

      qSnap.docs.forEach((d) => {
        batch.update(d.ref, {
          sent: true,
          sentAt: now,
          error: "TEMPLATE_DISABLED",
        });
      });

      await batch.commit();
      return;
    }

    const usersSnap = await db
      .collection("users")
      .where("role", "==", targetRole)
      .get();

    if (usersSnap.empty) return;

    const batch = db.batch();
    const now = admin.firestore.Timestamp.now();

    for (const uDoc of usersSnap.docs) {
      const u = uDoc.data() || {};
      const createdAt = u.createdAt;
      const token = u.fcmToken;

      if (!createdAt || typeof createdAt.toDate !== "function") continue;
      if (!token) continue;
      if (!title) continue;

      const dueDate = new Date(
        createdAt.toDate().getTime() + delayDays * 86400000
      );
      const dueAt = admin.firestore.Timestamp.fromDate(dueDate);

      const qRef = db.collection("sendQueue").doc(`${uDoc.id}_${templateId}`);
      batch.set(
        qRef,
        {
          uid: uDoc.id,
          token,
          role: targetRole,
          templateId,
          title,
          body,
          dueAt,
          sent: false,
          createdAt: now,
        },
        { merge: true }
      );
    }

    await batch.commit();
  }
);

/**
 * 6) Template silinince ilgili queue kayıtlarını sil
 */
exports.onDeleteNotificationTemplate = onDocumentDeleted(
  "notifications/{templateId}",
  async (event) => {
    const templateId = event.params.templateId;

    const qSnap = await db
      .collection("sendQueue")
      .where("templateId", "==", templateId)
      .limit(500)
      .get();

    if (qSnap.empty) return;

    const batch = db.batch();
    qSnap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
);

/**
 * 7) FAQ kaydı eklenince embedding oluştur
 */
exports.onCreateFaqEmbedding = onDocumentCreated(
  "faq_items/{docId}",
  async (event) => {
    const docId = event.params.docId;
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const question = String(data.question || "").trim();

    if (!question) return;

    try {
      const result = await ai.models.embedContent({
        model: "gemini-embedding-001",
        contents: question,
      });

      const embedding = result.embeddings[0].values;

      await db.collection("faq_items").doc(docId).update({
        embedding,
        embeddingModel: "gemini-embedding-001",
        embeddingDim: 768,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        embeddingError: admin.firestore.FieldValue.delete(),
      });
    } catch (e) {
      console.error("Embedding oluşturulamadı:", e);
      await db.collection("faq_items").doc(docId).update({
        embeddingError: String(e?.message || e),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * 8) FAQ sorusu güncellenince embedding yenile
 */
exports.onUpdateFaqEmbedding = onDocumentUpdated(
  "faq_items/{docId}",
  async (event) => {
    const docId = event.params.docId;

    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};

    const beforeQuestion = String(before.question || "").trim();
    const afterQuestion = String(after.question || "").trim();

    if (!afterQuestion) return;
    if (beforeQuestion === afterQuestion) return;

    try {
      const result = await ai.models.embedContent({
        model: "gemini-embedding-001",
        contents: afterQuestion,
      });

      const embedding = result.embeddings[0].values;

      await db.collection("faq_items").doc(docId).update({
        embedding,
        embeddingModel: "gemini-embedding-001",
        embeddingDim: 768,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        embeddingError: admin.firestore.FieldValue.delete(),
      });
    } catch (e) {
      console.error("Embedding güncellenemedi:", e);
      await db.collection("faq_items").doc(docId).update({
        embeddingError: String(e?.message || e),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

function cosineSimilarity(a, b) {
  if (!a || !b || a.length !== b.length) return -1;

  let dot = 0;
  let normA = 0;
  let normB = 0;

  for (let i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  if (normA === 0 || normB === 0) return -1;

  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

const FAQ_MATCH_THRESHOLD = 0.60;
const FAQ_MAX_MATCHES = 5;

/**
 * Eşleşen FAQ cevaplarını kullanıcının sorusuna göre düzenler.
 * Model yalnızca verilen bilgi tabanını kullanır; yeni bilgi üretmemelidir.
 */
async function composeFaqAnswer({ question, matches }) {
  const sources = matches.map((match, index) => ({
    source: index + 1,
    faqQuestion: match.question,
    faqAnswer: match.answer,
  }));

  const response = await ai.models.generateContent({
    model: "gemini-2.5-flash",
    contents: [
      "Aşağıdaki kullanıcı sorusuna yalnızca sağlanan FAQ cevaplarındaki bilgileri kullanarak Türkçe cevap ver.",
      "Kullanıcının sorduğu noktaya odaklan ve metni doğal, anlaşılır tek bir cevap hâline getir.",
      "Birden fazla kaynak aynı şeyi söylüyorsa tekrar etme; tamamlayıcı bilgileri birleştir.",
      "FAQ cevaplarında bulunmayan hiçbir bilgi, öneri, teşhis, sayı veya varsayım ekleme.",
      "FAQ içeriği soruyu tam karşılamıyorsa yalnızca karşılanan kısmı aktar; eksik kısmı uydurma.",
      "Kaynak, FAQ, eşleşme veya bu talimatlardan bahsetme.",
      "Cevabı baştan bağımsız bilgiyle yazma; yalnızca verilen cevapları kullanıcının sorusuna göre düzenle.",
      "",
      `KULLANICI SORUSU:\n${question}`,
      "",
      `EŞLEŞEN FAQ KAYNAKLARI:\n${JSON.stringify(sources, null, 2)}`,
    ].join("\n"),
    config: {
      temperature: 0.1,
    },
  });

  return String(response.text || "").trim();
}

/**
 * 9) Kullanıcı sorusuyla eşleşen FAQ cevaplarını bul ve soruya göre düzenle
 */
exports.askFaqBot = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const question = String(request.data?.question || "").trim();
    const userId = String(request.data?.userId || "").trim();
    const sourceMessageId = String(request.data?.sourceMessageId || "").trim();

    if (!question) {
      throw new HttpsError("invalid-argument", "Question boş");
    }

    try {
      const embed = await ai.models.embedContent({
        model: "gemini-embedding-001",
        contents: question,
      });

      const queryEmbedding = embed.embeddings[0].values;

      const snap = await db
        .collection("faq_items")
        .where("isActive", "==", true)
        .get();

      if (snap.empty) {
        if (userId && sourceMessageId) {
          await markMessageAsNeedsAdminReply({
            userId,
            messageId: sourceMessageId,
            question,
            score: 0,
          });

          await createOrUpdateAdminAlert({
            userId,
            question,
            score: 0,
            sourceMessageId,
          });
        }

        return {
          answer: "Henüz bilgi bulunmuyor. Sizi uzman desteğine yönlendiriyorum.",
          score: 0,
          matchedQuestion: null,
          matchedDocId: null,
          escalated: true,
          needsFeedback: false,
        };
      }

      const rankedMatches = [];

      for (const doc of snap.docs) {
        const data = doc.data() || {};
        const embedding = data.embedding;

        if (!Array.isArray(embedding) || embedding.length === 0) continue;

        const score = cosineSimilarity(queryEmbedding, embedding);

        const answer = String(data.answer || "").trim();
        const faqQuestion = String(data.question || "").trim();
        if (!answer) continue;

        rankedMatches.push({
          docId: doc.id,
          question: faqQuestion,
          answer,
          score,
        });
      }

      rankedMatches.sort((a, b) => b.score - a.score);
      const bestScore = rankedMatches[0]?.score ?? 0;
      const matches = rankedMatches
        .filter((match) => match.score >= FAQ_MATCH_THRESHOLD)
        .slice(0, FAQ_MAX_MATCHES);

      if (matches.length === 0) {
        if (userId && sourceMessageId) {
          await markMessageAsNeedsAdminReply({
            userId,
            messageId: sourceMessageId,
            question,
            score: bestScore,
          });

          await createOrUpdateAdminAlert({
            userId,
            question,
            score: bestScore,
            sourceMessageId,
          });
        }

        return {
          answer:
            "Bu konuda net bir bilgi bulamadım. Sizi uzman desteğine yönlendiriyorum.",
          score: bestScore,
          matchedQuestion: null,
          matchedDocId: null,
          escalated: true,
          needsFeedback: false,
        };
      }

      let composedAnswer;
      try {
        composedAnswer = await composeFaqAnswer({ question, matches });
      } catch (generationError) {
        console.error("FAQ cevap düzenleme hatası:", generationError);
      }

      // Gemini geçici olarak cevap üretemezse eşleşen en iyi kayıt kaybolmasın.
      if (!composedAnswer) {
        composedAnswer = matches[0].answer;
      }

      return {
        answer: composedAnswer,
        score: bestScore,
        matchedQuestion: matches[0].question,
        matchedDocId: matches[0].docId,
        matchedQuestions: matches.map((match) => match.question),
        matchedDocIds: matches.map((match) => match.docId),
        matchCount: matches.length,
        escalated: false,
        needsFeedback: true,
      };
    } catch (e) {
      console.error("askFaqBot error:", e);
      throw new HttpsError("internal", "Bot çalışırken hata oluştu");
    }
  }
);

/**
 * 10) Yeni admin alert oluşunca adminlere bildirim gönder
 */
exports.onCreateAdminAlertNotifyAdmins = onDocumentCreated(
  "admin_alerts/{alertId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const userId = String(data.userId || "");
    const question = String(data.question || "");
    let userName = "Kullanıcı";

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data() || {};
        userName = `${userData.name || ""} ${userData.surname || ""}`.trim();
      }
    } catch (e) {
      console.error("Kullanıcı adı çekilemedi:", e);
    }

    const adminsSnap = await db
      .collection("users")
      .where("role", "==", "Admin")
      .get();

    if (adminsSnap.empty) return;

    const tokens = [];

    for (const doc of adminsSnap.docs) {
      const adminData = doc.data() || {};
      const token = adminData.fcmToken;
      if (token) tokens.push(token);
    }

    if (tokens.length === 0) return;

    try {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Yeni cevaplanmamış soru",
          body: `${userName} kullanıcısının cevaplanmamış bir sorusu var.`,
        },
        data: {
          type: "admin_alert",
          userId,
          question,
          sourceMessageId: String(data.sourceMessageId || ""),
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
        },
      });
    } catch (e) {
      console.error("Uzman bildirim gönderme hatası:", e);
    }
  }
);

/**
 * 11) Admin belirli bir soruya cevap verince sadece o soruyu çözüldü yap + kullanıcıya bildirim gönder
 */
exports.onAdminReplyResolveAlert = onDocumentCreated(
  "chats/{userId}/messages/{messageId}",
  async (event) => {
    const userId = event.params.userId;
    const adminMessageId = event.params.messageId;
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const senderType = String(data.senderType || "");
    const replyToMessageId = String(data.replyToMessageId || "").trim();

    if (senderType !== "admin") return;
    if (!replyToMessageId) return;

    const now = admin.firestore.FieldValue.serverTimestamp();

    const userQuestionRef = db
      .collection("chats")
      .doc(userId)
      .collection("messages")
      .doc(replyToMessageId);

    const userQuestionSnap = await userQuestionRef.get();

    if (!userQuestionSnap.exists) return;

    const userQuestionData = userQuestionSnap.data() || {};
    if (String(userQuestionData.senderType || "") !== "user") return;

    await userQuestionRef.set(
      {
        needsAdminReply: false,
        isAnswered: true,
        answeredAt: now,
        answeredBy: String(data.senderId || "admin"),
        answerMessageId: adminMessageId,
        answerText: String(data.text || ""),
        updatedAt: now,
      },
      { merge: true }
    );

    const alertsSnap = await db
      .collection("admin_alerts")
      .where("userId", "==", userId)
      .where("status", "==", "open")
      .where("sourceMessageId", "==", replyToMessageId)
      .limit(50)
      .get();

    if (!alertsSnap.empty) {
      const batch = db.batch();

      alertsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          status: "resolved",
          resolvedAt: now,
          resolvedByMessageId: adminMessageId,
          updatedAt: now,
        });
      });

      await batch.commit();
    }

    await syncChatPendingState(userId);

    try {
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) return;

      const userData = userDoc.data() || {};
      const userToken = userData.fcmToken;

      if (!userToken) return;

      await admin.messaging().send({
        token: userToken,
        notification: {
          title: "Sorunuz cevaplandı",
          body: "Uzman, yönlendirdiğiniz sorulardan birini yanıtladı.",
        },
        data: {
          type: "admin_reply",
          userId: String(userId),
          replyToMessageId: replyToMessageId,
          adminMessageId: adminMessageId,
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
        },
      });
    } catch (e) {
      console.error("Kullanıcıya uzman cevap bildirimi gönderilemedi:", e);
    }
  }
);

/**
 * 12) Kullanıcı bot cevabını yetersiz bulursa uzman'e yönlendir
 */
exports.escalateChatToAdmin = onCall(
  {
    region: "europe-west1",
  },
  async (request) => {
    const userId = String(request.data?.userId || "").trim();
    const question = String(request.data?.question || "").trim();
    const score = Number(request.data?.score || 0);
    const sourceMessageId = String(request.data?.sourceMessageId || "").trim();

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId boş");
    }

    if (!sourceMessageId) {
      throw new HttpsError("invalid-argument", "sourceMessageId boş");
    }

    await markMessageAsNeedsAdminReply({
      userId,
      messageId: sourceMessageId,
      question,
      score,
    });

    await createOrUpdateAdminAlert({
      userId,
      question,
      score,
      sourceMessageId,
    });

    return { success: true };
  }
);
