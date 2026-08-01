import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

class LoginHistoryPage extends StatelessWidget {
  final String userId;

  const LoginHistoryPage({super.key, required this.userId});

  String _formatTs(dynamic ts) {
    if (ts == null) return "-";
    if (ts is! Timestamp) return "-";
    final date = ts.toDate();
    return "${date.day.toString().padLeft(2, '0')}."
        "${date.month.toString().padLeft(2, '0')}."
        "${date.year}  "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final historyRef = FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("loginHistory")
        .orderBy("createdAt", descending: true); //en yeni -> en eski

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgBlue, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),

              // Header (senin tasarımın gibi)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textBlue),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Giriş Geçmişi",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // sağ denge boşluğu
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.history, size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              "Son girişler",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot>(
                          stream: historyRef.snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text(
                                "Hata: ${snapshot.error}",
                                style: const TextStyle(color: Colors.red),
                              );
                            }

                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Text(
                                "Henüz giriş kaydı yok.",
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            return Column(
                              children: docs.map((d) {
                                final m = d.data() as Map<String, dynamic>;
                                final timeText = _formatTs(m["createdAt"]);

                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgBlue.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.login, color: AppColors.textBlue),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          timeText,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}