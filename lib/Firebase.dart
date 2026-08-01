import 'package:cloud_firestore/cloud_firestore.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

Future<void> addUser({
  required String uid,
  required String email,
  required String role,
}) async {
  await _firestore.collection('users').doc(uid).set({
    'email': email,
    'role': role, // mother / elder / admin
    'createdAt': FieldValue.serverTimestamp(),
  });
}
