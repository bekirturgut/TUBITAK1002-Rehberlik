const crypto = require('node:crypto');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

function normalizePhone(value) {
  let phone = String(value || '').replace(/[\s()-]/g, '');
  if (phone.startsWith('0')) phone = phone.slice(1);
  if (!phone.startsWith('+')) phone = phone.startsWith('90') ? '+' + phone : '+90' + phone;
  if (!/^\+90[0-9]{10}$/.test(phone)) {
    throw new HttpsError('invalid-argument', 'Geçerli bir Türkiye telefon numarası girin.');
  }
  return phone;
}

function loginEmail(phone) {
  return crypto.createHash('sha256').update(normalizePhone(phone)).digest('hex') + '@accounts.lactigen.invalid';
}

async function requireProfile(request, adminOnly = false) {
  if (!request.auth?.uid) throw new HttpsError('unauthenticated', 'Giriş yapmanız gerekiyor.');
  const profile = await admin.firestore().doc('users/' + request.auth.uid).get();
  if (!profile.exists || profile.data().deletionInProgress === true) {
    throw new HttpsError('permission-denied', 'Hesaba erişim yok.');
  }
  if (adminOnly && profile.data().role !== 'Admin') {
    throw new HttpsError('permission-denied', 'Yönetici yetkisi gerekiyor.');
  }
  return profile;
}

const saveManagedUser = onCall({region: 'europe-west1'}, async request => {
  await requireProfile(request, true);
  const input = request.data || {};
  const role = String(input.role || '');
  if (!['Anne', 'Üst Kuşak', 'Admin'].includes(role)) throw new HttpsError('invalid-argument', 'Geçersiz rol.');
  const phone = normalizePhone(input.phone);
  const name = String(input.name || '').trim();
  const surname = String(input.surname || '').trim();
  const password = String(input.password || '');
  if (!name || name.length > 100 || surname.length > 100) throw new HttpsError('invalid-argument', 'Ad ve soyadı kontrol edin.');
  if (password && (password.length < 6 || password.length > 128)) throw new HttpsError('invalid-argument', 'Şifre 6–128 karakter olmalı.');
  const db = admin.firestore();
  const uid = String(input.userId || '').trim();
  if (uid.includes('/')) throw new HttpsError('invalid-argument', 'Geçersiz kullanıcı.');
  const ref = uid ? db.doc('users/' + uid) : db.collection('users').doc();
  const previous = await ref.get();
  if (uid && !previous.exists) throw new HttpsError('not-found', 'Kullanıcı bulunamadı.');
  if (!uid && !password) throw new HttpsError('invalid-argument', 'Yeni hesap için şifre gerekir.');
  if (ref.id === request.auth.uid && role !== 'Admin') throw new HttpsError('failed-precondition', 'Kendi yönetici yetkinizi kaldıramazsınız.');
  const duplicate = await db.collection('users').where('phone', '==', phone).get();
  if (duplicate.docs.some(doc => doc.id !== ref.id)) throw new HttpsError('already-exists', 'Bu telefon numarası kullanılıyor.');
  const auth = admin.auth();
  const account = {email: loginEmail(phone), displayName: [name, surname].filter(Boolean).join(' '), ...(password ? {password} : {})};
  if (uid) await auth.updateUser(ref.id, account);
  else await auth.createUser({uid: ref.id, ...account});
  await ref.set({name, surname, phone, role, updatedAt: admin.firestore.FieldValue.serverTimestamp(), ...(!uid ? {createdAt: admin.firestore.FieldValue.serverTimestamp()} : {})}, {merge: true});
  return {userId: ref.id};
});

const deleteManagedUser = onCall({region: 'europe-west1', timeoutSeconds: 300}, async request => {
  await requireProfile(request, true);
  const uid = String(request.data?.userId || '');
  if (!uid || uid.includes('/') || uid === request.auth.uid) throw new HttpsError('invalid-argument', 'Bu hesap silinemez.');
  const db = admin.firestore();
  const ref = db.doc('users/' + uid);
  const profile = await ref.get();
  if (profile.exists) await ref.update({deletionInProgress: true});
  // Block new client writes before deleting subcollections and queued notifications.
  try {await admin.auth().updateUser(uid, {disabled: true}); await admin.auth().revokeRefreshTokens(uid);} catch (e) {if (e.code !== 'auth/user-not-found') throw e;}
  await db.recursiveDelete(db.doc('chats/' + uid));
  for (const [collection, field] of [['sendQueue', 'uid'], ['admin_alerts', 'userId'], ['content_reports', 'userId'], ['deletion_requests', 'userId']]) {
    const records = await db.collection(collection).where(field, '==', uid).get();
    for (const record of records.docs) await db.recursiveDelete(record.ref);
  }
  await db.recursiveDelete(ref);
  try {await admin.auth().deleteUser(uid);} catch (e) {if (e.code !== 'auth/user-not-found') throw e;}
  return {deleted: true};
});

module.exports = {normalizePhone, loginEmail, requireProfile, saveManagedUser, deleteManagedUser};
