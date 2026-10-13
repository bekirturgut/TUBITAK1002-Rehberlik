import 'package:cloud_firestore/cloud_firestore.dart';

class UserRequests {
  static Future<void> reportContent({
    required String userId,
    required String messageId,
    required String reason,
  }) async {
    final ref = FirebaseFirestore.instance
        .collection('content_reports')
        .doc('${userId}_$messageId');
    if ((await ref.get()).exists) return;
    await ref.set({
      'userId': userId,
      'messageId': messageId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> requestDeletion(String userId) async {
    final ref = FirebaseFirestore.instance
        .collection('deletion_requests')
        .doc(userId);
    if ((await ref.get()).exists) return;
    await ref.set({
      'userId': userId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
