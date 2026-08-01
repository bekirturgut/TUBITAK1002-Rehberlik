import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FcmTokenService {
  FcmTokenService._();

  static const String _prefsKeyLastToken = "last_fcm_token";
  static const String _prefsKeyLastUid = "last_fcm_uid";

  ///Firestore'a sadece gerektiğinde yazar:
  /// - Token değiştiyse yazar
  /// - UID değiştiyse (başka kullanıcıyla login) yazar
  /// - Token refresh olursa otomatik yazar
  static Future<void> syncIfNeeded(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final messaging = FirebaseMessaging.instance;

      //Android 13+ / iOS izin
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      //Token al
      final token = await messaging.getToken();
      debugPrint("FCM getToken: $token");

      if (token == null || token.isEmpty) return;

      final lastToken = prefs.getString(_prefsKeyLastToken);
      final lastUid = prefs.getString(_prefsKeyLastUid);

      //Token aynı ve uid aynıysa tekrar yazma
      if (lastToken == token && lastUid == uid) {
        debugPrint("FCM token değişmedi → Firestore write yok");
      } else {
        await _writeToken(uid: uid, token: token);
        await prefs.setString(_prefsKeyLastToken, token);
        await prefs.setString(_prefsKeyLastUid, uid);
        debugPrint("FCM token değişti → Firestore'a yazıldı");
      }

      //Token yenilenirse otomatik güncelle (değiştiyse)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          if (newToken.isEmpty) return;

          final last = prefs.getString(_prefsKeyLastToken);
          final lastU = prefs.getString(_prefsKeyLastUid);

          if (last == newToken && lastU == uid) {
            debugPrint("onTokenRefresh geldi ama aynı → yazma yok");
            return;
          }

          await _writeToken(uid: uid, token: newToken);
          await prefs.setString(_prefsKeyLastToken, newToken);
          await prefs.setString(_prefsKeyLastUid, uid);

          debugPrint("FCM token refresh → Firestore'a yazıldı");
        } catch (e) {
          debugPrint("onTokenRefresh error: $e");
        }
      });
    } catch (e) {
      debugPrint("FcmTokenService.syncIfNeeded error: $e");
    }
  }

  static Future<void> _writeToken({
    required String uid,
    required String token,
  }) async {
    final userRef = FirebaseFirestore.instance.collection("users").doc(uid);

    await userRef.set({
      "fcmToken": token,
      "fcmUpdatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}