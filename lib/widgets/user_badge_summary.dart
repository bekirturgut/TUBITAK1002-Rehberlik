import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants.dart';

class UserBadgeSummary extends StatelessWidget {
  final String userId;

  const UserBadgeSummary({super.key, required this.userId});

  static const _levels = [25, 50, 75, 100];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        final stats =
            snapshot.data?.data()?['quizStats'] as Map<String, dynamic>? ?? {};
        final percent = (stats['percent'] as num?)?.toInt() ?? 0;
        final latest = (stats['latestBadge'] as num?)?.toInt();
        final earned = ((stats['earnedBadges'] as List?) ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .toSet();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          latest == null
                              ? 'Henüz rozet kazanılmadı • %$percent'
                              : 'Son rozet: %$latest Bilgi Ustası',
                          style: const TextStyle(
                            color: AppColors.textBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Kazanılan rozetler',
                onPressed: () => _showBadges(context, earned, percent),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.textBlue,
                ),
                icon: const Icon(
                  Icons.military_tech_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBadges(BuildContext context, Set<int> earned, int percent) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kazanılan Rozetler',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text('Doğru bilme oranınız: %$percent'),
            const SizedBox(height: 18),
            ..._levels.map(
              (level) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: earned.contains(level)
                      ? Colors.amber.shade100
                      : Colors.grey.shade200,
                  child: Icon(
                    earned.contains(level)
                        ? Icons.workspace_premium
                        : Icons.lock_outline,
                    color: earned.contains(level)
                        ? Colors.orange.shade800
                        : Colors.grey,
                  ),
                ),
                title: Text('%$level Bilgi Ustası'),
                subtitle: Text(
                  earned.contains(level)
                      ? 'Kazanıldı'
                      : 'Soruların %$level kadarını doğru bilince açılır.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
