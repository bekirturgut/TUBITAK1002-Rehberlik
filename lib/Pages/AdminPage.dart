import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubitak/Pages/ChatbotTab.dart';
import 'package:tubitak/Pages/SSSTab.dart';
import '../constants.dart';
import 'GameCardsTab.dart';
import 'LoginPage.dart';
import 'UsersTab.dart';
import 'NotificationsTab.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _index = 0;

  final _pages = const [
    UsersTab(),
    GameCardsTab(),
    SSSTab(),
    ChatbotTab(),
    NotificationsTab(),
  ];

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // ya da sadece uid/role/rememberMe sil
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlue,
      appBar: AppBar(
        title: const Text(
          "Uzman Paneli",
          style: TextStyle(
            color: AppColors.textBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          )
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_index],
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: Offset(0, -2),
                color: Colors.black12,
              )
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            currentIndex: _index,
            selectedItemColor: AppColors.textBlue,
            unselectedItemColor: Colors.blueGrey,
            showUnselectedLabels: true,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.people_alt),
                label: "Üyeler",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.extension),
                label: "Oyun Kartları",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.quiz),
                label: "SSS",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy),
                label: "Chatbot",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active),
                label: "Bildirimler",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
