import 'package:shared_preferences/shared_preferences.dart';

const privacyVersion = '2026-10-13-v2';

class PrivacyConsent {
  static String key(String userId) =>
      'gemini_consent_${privacyVersion}_$userId';
  static Future<bool> isGranted(String userId) async =>
      (await SharedPreferences.getInstance()).getBool(key(userId)) == true;
  static Future<void> setGranted(String userId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key(userId), value);
    if (value) {
      await prefs.setString(
        '${key(userId)}_accepted_at',
        DateTime.now().toUtc().toIso8601String(),
      );
    } else {
      await prefs.remove('${key(userId)}_accepted_at');
    }
  }
}
