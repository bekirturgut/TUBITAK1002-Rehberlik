import 'package:cloud_firestore/cloud_firestore.dart';

class QuizProgressService {
  QuizProgressService._();

  static const badgeThresholds = [25, 50, 75, 100];

  static Future<void> recordAnswer({
    required String userId,
    required String cardId,
    required String collectionName,
    required String question,
    required String answer,
    required bool isCorrect,
    required int assignedCount,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(userId);
    final progressId = '${collectionName}_$cardId';
    final correctRef = userRef.collection('correctCards').doc(progressId);
    final wrongRef = userRef.collection('wrongCards').doc(progressId);
    final now = FieldValue.serverTimestamp();
    final batch = firestore.batch();

    final data = <String, dynamic>{
      'cardId': cardId,
      'collectionName': collectionName,
      'question': question,
      'answer': answer,
      'updatedAt': now,
    };

    if (isCorrect) {
      batch.set(correctRef, {
        ...data,
        'correctAt': now,
      }, SetOptions(merge: true));
      batch.delete(wrongRef);
    } else {
      batch.set(wrongRef, {
        ...data,
        'wrongAt': now,
        'nextReviewAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
      }, SetOptions(merge: true));
      batch.delete(correctRef);
    }

    await batch.commit();
    await refreshStats(userId: userId, assignedCount: assignedCount);
  }

  static Future<void> refreshStats({
    required String userId,
    required int assignedCount,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final results = await Future.wait([
      userRef.collection('correctCards').count().get(),
      userRef.collection('wrongCards').count().get(),
      userRef.get(),
    ]);

    final correctCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
    final wrongCount = (results[1] as AggregateQuerySnapshot).count ?? 0;
    final userData = (results[2] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    final percent = assignedCount == 0
        ? 0
        : ((correctCount / assignedCount) * 100).clamp(0, 100).round();
    final currentlyQualified = badgeThresholds
        .where((value) => percent >= value)
        .toList();
    final previous = List<int>.from(
      ((userData?['quizStats'] as Map<String, dynamic>?)?['earnedBadges']
                  as List?)
              ?.whereType<num>()
              .map((value) => value.toInt()) ??
          const <int>[],
    );
    final earnedBadges = <int>{...previous, ...currentlyQualified}.toList()
      ..sort();
    final newlyEarned = earnedBadges
        .where((value) => !previous.contains(value))
        .toList();
    final latestBadge = newlyEarned.isNotEmpty
        ? newlyEarned.last
        : (earnedBadges.isNotEmpty ? earnedBadges.last : null);

    await userRef.set({
      'quizStats': {
        'assignedCount': assignedCount,
        'correctCount': correctCount,
        'wrongCount': wrongCount,
        'percent': percent,
        'earnedBadges': earnedBadges,
        'latestBadge': latestBadge,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }
}
