import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'fcm_token_service.dart';

import 'local_notifications.dart';

class NotificationBootstrap {
  /// Temiz, basit:
  /// - Firestore’daki aktif template’leri çeker
  /// - users/{uid}/scheduledNotifs/{templateId} ile tekrar schedule’i engeller
  /// - EK: FCM token alıp users/{uid}.fcmToken alanına yazar (push için)
  static Future<void> sync({
    required BuildContext context,
    required String uid,
  }) async {
    //Local notification permission (Android 13+)
    await LocalNotifs.instance.requestPermissionAndroid13Plus();

    //Push için token senkronla (uygulama kapalıyken push gelebilmesi için şart)
    await FcmTokenService.syncIfNeeded(uid);

    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);
    final userDoc = await userRef.get();
    final user = userDoc.data();
    if (user == null) return;

    final role = (user["role"] ?? "").toString();
    final createdAtTs = user["createdAt"];
    if (role.isEmpty || createdAtTs is! Timestamp) return;

    final createdAt = createdAtTs.toDate();
    final now = DateTime.now();

    //daha önce planlananları oku
    final scheduledRef = userRef.collection("scheduledNotifs");
    final scheduledSnap = await scheduledRef.get();
    final already = <String>{for (final d in scheduledSnap.docs) d.id};

    //aktif template’leri çek
    final templatesSnap = await FirebaseFirestore.instance
        .collection("notifications")
        .where("targetRole", isEqualTo: role)
        .where("isActive", isEqualTo: true)
        .get();

    for (final doc in templatesSnap.docs) {
      final templateId = doc.id;
      if (already.contains(templateId)) continue; //tekrar kurma

      final data = doc.data();
      final title = (data["title"] ?? "").toString();
      final body = (data["body"] ?? "").toString();

      // Firestore bazen int yerine num döndürebilir
      final delayRaw = data["delayDays"];
      final delayDays = (delayRaw is int)
          ? delayRaw
          : (delayRaw is num)
          ? delayRaw.toInt()
          : 0;

      final dueAt = createdAt.add(Duration(days: delayDays));

      // geçmişse: tekrar denememek için kayıt aç (istersen “hemen göster” de yapabiliriz)
      if (dueAt.isBefore(now)) {
        await scheduledRef.doc(templateId).set({
          "templateId": templateId,
          "dueAt": Timestamp.fromDate(dueAt),
          "scheduledAt": FieldValue.serverTimestamp(),
          "skippedBecausePast": true,
        });
        continue;
      }

      final localId = LocalNotifs.instance.makeStableId(uid, templateId);

      await LocalNotifs.instance.schedule(
        id: localId,
        title: title,
        body: body,
        dateTime: dueAt,
      );

      //“planlandı” kaydı
      await scheduledRef.doc(templateId).set({
        "templateId": templateId,
        "dueAt": Timestamp.fromDate(dueAt),
        "scheduledAt": FieldValue.serverTimestamp(),
        "localId": localId,
        "skippedBecausePast": false,
      });
    }
  }
}
