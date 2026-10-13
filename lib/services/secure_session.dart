import 'fcm_token_service.dart';
import 'local_notifications.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionProfile {
  final String userId;
  final String role;
  const SessionProfile(this.userId, this.role);
}

class SecureSession {
  static String loginEmail(String phone) =>
      '${sha256.convert(utf8.encode(phone))}@accounts.lactigen.invalid';

  static Future<SessionProfile> signIn({
    required String phone,
    required String password,
    required String selectedRole,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail(phone),
        password: password,
      );
      final profile = await restoredProfile();
      if (profile == null || profile.role != selectedRole) {
        await signOut();
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Telefon, şifre ve rolü kontrol edin.',
        );
      }
      return profile;
    } on FirebaseAuthException {
      await signOut();
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Telefon, şifre ve rolü kontrol edin.',
      );
    }
  }

  static Future<SessionProfile?> restoredProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      await user.getIdToken(true);
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null ||
          data['deletionInProgress'] == true ||
          !['Anne', 'Üst Kuşak', 'Admin'].contains(data['role'])) {
        await signOut();
        return null;
      }
      return SessionProfile(user.uid, data['role'] as String);
    } catch (_) {
      await signOut();
      return null;
    }
  }

  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;
    await FcmTokenService.stop();
    try {
      await LocalNotifs.instance.cancelAll();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }
}
