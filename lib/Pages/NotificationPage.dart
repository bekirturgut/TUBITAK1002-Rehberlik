import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  final String userId;
  const NotificationsPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFFFFF9F2);
    const Color textColor = Color(0xFF4A628A);
    const Color softPink = Color(0xFFFFE7EF);
    const Color softBlue = Color(0xFFE6F4FF);
    const Color softYellow = Color(0xFFFFF3CC);
    const Color softGreen = Color(0xFFDFF5EA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection("users").doc(userId).get(),
                builder: (context, userSnap) {
                  if (userSnap.hasError) {
                    return _buildInfoState("Kullanıcı okunamadı: ${userSnap.error}");
                  }

                  if (userSnap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!userSnap.hasData || !userSnap.data!.exists) {
                    return _buildInfoState("Kullanıcı bulunamadı.");
                  }

                  final userData = userSnap.data!.data() ?? {};
                  final role = (userData["role"] ?? "").toString();
                  final createdTs = userData["createdAt"];

                  if (role.isEmpty) {
                    return _buildInfoState("Kullanıcı rol bilgisi eksik.");
                  }

                  if (createdTs == null || createdTs is! Timestamp) {
                    return _buildInfoState(
                      "Kayıt tarihi henüz oluşmadı.\nLütfen tekrar deneyin.",
                    );
                  }

                  final createdAt = (createdTs).toDate();
                  final now = DateTime.now();

                  final notifQuery = FirebaseFirestore.instance
                      .collection("notifications")
                      .where("targetRole", isEqualTo: role)
                      .where("isActive", isEqualTo: true);

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: notifQuery.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return _buildInfoState("Bildirimler okunamadı: ${snap.error}");
                      }

                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return _buildEmptyState();
                      }

                      final arrived = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                      final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                      for (final d in docs) {
                        final data = d.data();
                        final delayDays = (data["delayDays"] ?? 0) as int;
                        final dueAt = createdAt.add(Duration(days: delayDays));

                        if (now.isAfter(dueAt) || now.isAtSameMomentAs(dueAt)) {
                          arrived.add(d);
                        } else {
                          upcoming.add(d);
                        }
                      }

                      arrived.sort((a, b) {
                        final da = (a.data()["delayDays"] ?? 0) as int;
                        final db = (b.data()["delayDays"] ?? 0) as int;
                        return db.compareTo(da);
                      });

                      upcoming.sort((a, b) {
                        final da = (a.data()["delayDays"] ?? 0) as int;
                        final db = (b.data()["delayDays"] ?? 0) as int;
                        return da.compareTo(db);
                      });

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        children: [
                          _buildTopInfoCard(
                            role: role,
                            arrivedCount: arrived.length,
                            upcomingCount: upcoming.length,
                            colors: const [softPink, softYellow, softBlue],
                          ),
                          const SizedBox(height: 18),

                          _sectionHeader(
                            title: "Gelen Bildirimler",
                            subtitle: "Şu anda görüntüleyebileceğiniz bildirimler",
                            icon: Icons.notifications_active_rounded,
                            bgColor: softGreen,
                          ),
                          const SizedBox(height: 12),

                          if (arrived.isEmpty)
                            _buildMiniEmptyCard("Henüz zamanı gelen bildirim yok.")
                          else
                            ...arrived.map((d) {
                              final data = d.data();
                              final title = (data["title"] ?? "").toString();
                              final message = (data["body"] ?? "").toString();
                              final delayDays = (data["delayDays"] ?? 0) as int;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildNotificationCard(
                                  title: title,
                                  message: message,
                                  dayInfo: "$delayDays. gün bildirimi",
                                  faded: false,
                                  isUpcoming: false,
                                ),
                              );
                            }),

                          const SizedBox(height: 18),

                          _sectionHeader(
                            title: "Yaklaşan Bildirimler",
                            subtitle: "Henüz zamanı gelmemiş bildirimler",
                            icon: Icons.schedule_rounded,
                            bgColor: softBlue,
                          ),
                          const SizedBox(height: 12),

                          if (upcoming.isEmpty)
                            _buildMiniEmptyCard("Yaklaşan bildirim yok.")
                          else
                            ...upcoming.map((d) {
                              final data = d.data();
                              final title = (data["title"] ?? "").toString();
                              final message = (data["body"] ?? "").toString();
                              final delayDays = (data["delayDays"] ?? 0) as int;

                              final dueAt = createdAt.add(Duration(days: delayDays));
                              final daysLeft = dueAt.difference(now).inDays;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildNotificationCard(
                                  title: title,
                                  message: message,
                                  dayInfo: daysLeft <= 0 ? "Yakında" : "$daysLeft gün kaldı",
                                  faded: true,
                                  isUpcoming: true,
                                ),
                              );
                            }),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    const Color textColor = Color(0xFF4A628A);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE7EF),
            Color(0xFFFFF3CC),
            Color(0xFFE6F4FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              color: textColor,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bildirimler",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                Text(
                  "Senin için zamanlanan küçük hatırlatmalar ✨",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfoCard({
    required String role,
    required int arrivedCount,
    required int upcomingCount,
    required List<Color> colors,
  }) {
    const Color textColor = Color(0xFF4A628A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "Bildirim Takibin 🌸",
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$role rolüne özel bildirimlerin burada sıralanır.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.blueGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _tinyStatBox(
                  label: "Gelen",
                  value: "$arrivedCount",
                  icon: Icons.mark_email_read_rounded,
                  bg: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _tinyStatBox(
                  label: "Yaklaşan",
                  value: "$upcomingCount",
                  icon: Icons.hourglass_top_rounded,
                  bg: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tinyStatBox({
    required String label,
    required String value,
    required IconData icon,
    required Color bg,
  }) {
    const Color textColor = Color(0xFF4A628A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
  }) {
    const Color textColor = Color(0xFF4A628A);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: textColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String dayInfo,
    required bool faded,
    required bool isUpcoming,
  }) {
    const Color textColor = Color(0xFF4A628A);

    final cardGradient = isUpcoming
        ? const [Color(0xFFF9FCFF), Color(0xFFEFF7FF)]
        : const [Colors.white, Color(0xFFFFF9F4)];

    final accentColor = isUpcoming
        ? const Color(0xFF8FBCE6)
        : const Color(0xFF76BA99);

    return Opacity(
      opacity: faded ? 0.62 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: cardGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isUpcoming
                        ? Icons.notifications_paused_rounded
                        : Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.5,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  dayInfo,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    const Color textColor = Color(0xFF4A628A);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 42,
                color: textColor,
              ),
              SizedBox(height: 12),
              Text(
                "Henüz aktif bildirim yok",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Yeni bildirimler olduğunda burada tatlı tatlı görünecekler 🌷",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.blueGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.blueGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.blueGrey,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}