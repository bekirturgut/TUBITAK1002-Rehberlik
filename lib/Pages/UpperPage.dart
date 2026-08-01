import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubitak/Pages/ChatPage.dart';
import 'package:tubitak/Pages/LearnPage.dart';
import 'package:tubitak/Pages/LoginPage.dart';
import 'package:tubitak/Pages/NotificationPage.dart';
import 'package:tubitak/constants.dart';
import 'package:tubitak/widgets/user_badge_summary.dart';
import 'package:tubitak/widgets/app_animations.dart';
import 'SSSPage.dart';

class UpperPage extends StatefulWidget {
  final dynamic userId;
  final String selectedRole;
  const UpperPage({
    super.key,
    required this.userId,
    required this.selectedRole,
  });
  @override
  State<UpperPage> createState() => _UpperPageState();
}

class _UpperPageState extends State<UpperPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlue,

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.learnStart,
        icon: const Icon(Icons.help_outline),
        label: const Text("SSS"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SSSPage()),
          );
        },
      ),
      body: AnimatedPastelBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                EntranceAnimation(child: _buildTopGreetingFromFirestore()),
                EntranceAnimation(
                  delay: const Duration(milliseconds: 80),
                  child: UserBadgeSummary(userId: widget.userId.toString()),
                ),
                const SizedBox(height: 28),
                EntranceAnimation(
                  delay: const Duration(milliseconds: 150),
                  beginScale: 0.88,
                  child: GentleFloat(child: _buildHeartHeader()),
                ),
                const SizedBox(height: 20),
                EntranceAnimation(
                  delay: const Duration(milliseconds: 220),
                  child: _buildWelcomeSection(),
                ),
                const SizedBox(height: 40),

                // Buton Kartları
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    children: [
                      _buildMenuButton(
                        title: "Öğren",
                        subtitle: "Öğrenme Kartları",
                        icon: Icons.auto_stories,
                        colors: [AppColors.learnStart, AppColors.learnEnd],
                        textColor: AppColors.textBlue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LearnPage(userId: widget.userId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        title: "Danış",
                        subtitle: "YZ destekli sohbet robotu",
                        icon: Icons.chat_bubble_outline,
                        colors: [AppColors.consultStart, AppColors.consultEnd],
                        textColor: const Color(0xFF914F67),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                userId: widget.userId,
                                selectedRole: widget.selectedRole,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildMenuButton(
                        title: "Bildirimler",
                        subtitle: "Zamanlı hatırlatmalar",
                        icon: Icons.notifications_none,
                        colors: [AppColors.notifyStart, AppColors.notifyEnd],
                        textColor: const Color(0xFF388E3C),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  NotificationsPage(userId: widget.userId),
                            ),
                          );
                        },
                      ),

                      const SizedBox(
                        height: 40,
                      ), // Kartlarla çıkış butonu arası boşluk
                      // --- ÇIKIŞ YAP BUTONU ---
                      _buildLogoutButton(context),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Çıkış Yap Buton Tasarımı
  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // ya da sadece uid/role/rememberMe sil
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade200, width: 1.5),
          borderRadius: BorderRadius.circular(15),
          color: Colors.red.shade50.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 25),
            const SizedBox(width: 10),
            Text(
              "Çıkış Yap",
              style: TextStyle(
                color: Colors.red.shade400,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Önceki metodlar (Header, Welcome, MenuButton) aynen korunmuştur...
  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    final delay = switch (title) {
      "Öğren" => 300,
      "Danış" => 380,
      _ => 460,
    };

    return EntranceAnimation(
      delay: Duration(milliseconds: delay),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: colors[1].withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            child: Ink(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(icon, size: 40, color: textColor.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeartHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image.asset(
          "assets/foto1.png",
          width: constraints.maxWidth * 0.5, // ekranın %50’si
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        const Text(
          "Hoş geldiniz 🌸",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlue,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Doğum sonrası bu süreçte yanınızdayız.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textBlue.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTopGreetingFromFirestore() {
    final uid = widget.userId.toString();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        String fullName = "";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = (data["name"] ?? "").toString().trim();
          final surname = (data["surname"] ?? "").toString().trim();
          fullName = "$name $surname".trim();
        }

        return Column(
          children: [
            const SizedBox(height: 25),
            if (snapshot.connectionState == ConnectionState.waiting)
              Text(
                "Yükleniyor...",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textBlue.withValues(alpha: 0.7),
                ),
              )
            else
              Text(
                fullName.isEmpty ? "Kullanıcı" : fullName,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBlue.withValues(alpha: 0.85),
                ),
              ),
          ],
        );
      },
    );
  }
}
