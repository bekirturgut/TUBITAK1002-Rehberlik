import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tubitak/Pages/AdminPage.dart';
import 'package:tubitak/Pages/MotherPage.dart';
import 'package:tubitak/Pages/UpperPage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../services/fcm_token_service.dart';
import '../services/notification_bootstrap.dart';
import '../widgets/app_animations.dart';
import 'SSSPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? selectedRole;
  bool rememberMe = false;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  static const Color _pinkBtn = Color(0xFFF2A3B3);
  static const Color _greenBtn = Color(0xFFB8D9A0);
  static const Color _bgBlue = Color(0xFFE1F0F7);
  static const Color _textBlue = Color(0xFF4A628A);
  static const Color _adminBtn = Color(0xFF7987FF);

  @override
  void initState() {
    super.initState();
    _autoLoginIfRemembered();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => _loading = v);
  }

  String _normalizePhone(String input) {
    String phone = input.trim().replaceAll(" ", "");

    if (phone.isEmpty) return phone;

    if (phone.startsWith("+")) return phone;

    if (phone.startsWith("0")) {
      phone = phone.substring(1);
    }

    if (!phone.startsWith("90")) {
      phone = "90$phone";
    }

    return "+$phone";
  }

  Future<void> _writeLoginHistory(String uid) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("loginHistory")
        .add({"createdAt": FieldValue.serverTimestamp()});
  }

  void _goRolePage(String role, String uid) async {
    if (!mounted) return;

    if (role == "Anne") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MotherPage(userId: uid, selectedRole: "Anne"),
        ),
      );
    } else if (role == "Üst Kuşak") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UpperPage(userId: uid, selectedRole: "Üst Kuşak"),
        ),
      );
    } else if (role == "Admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminPage()),
      );
    }

    try {
      await FcmTokenService.syncIfNeeded(uid);
    } catch (e) {
      debugPrint("FCM sync error: $e");
    }

    try {
      await NotificationBootstrap.sync(context: context, uid: uid);
    } catch (e) {
      debugPrint("Notification bootstrap error: $e");
    }
  }

  Future<void> _autoLoginIfRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUid = prefs.getString('uid');
    final savedRole = prefs.getString('role');
    final isRemembered = prefs.getBool('rememberMe') ?? false;

    if (!mounted) return;

    if (isRemembered && savedUid != null && savedRole != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        try {
          await _writeLoginHistory(savedUid);
        } catch (_) {}

        _goRolePage(savedRole, savedUid);
      });
    }
  }

  Future<void> _login() async {
    final phone = _normalizePhone(_phoneController.text);
    final password = _passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      _showError("Telefon ve şifre giriniz");
      return;
    }
    if (selectedRole == null) {
      _showError("Rol seçiniz");
      return;
    }

    _setLoading(true);

    try {
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("phone", isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showError("Kullanıcı bulunamadı");
        _setLoading(false);
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();

      if (data["password"] != password) {
        _showError("Şifre yanlış");
        _setLoading(false);
        return;
      }

      if (data["role"] != selectedRole) {
        _showError("Bu rolde bu kullanıcı yok");
        _setLoading(false);
        return;
      }

      final uid = doc.id;
      final role = (data["role"] ?? "").toString();

      final prefs = await SharedPreferences.getInstance();
      if (rememberMe) {
        await prefs.setBool('rememberMe', true);
        await prefs.setString('uid', uid);
        await prefs.setString('role', role);
        await prefs.setString('phone', phone);
      } else {
        await prefs.remove('rememberMe');
        await prefs.remove('uid');
        await prefs.remove('role');
        await prefs.remove('phone');
      }

      try {
        await _writeLoginHistory(uid);
      } catch (_) {}

      _goRolePage(role, uid);
    } on FirebaseException catch (e) {
      debugPrint("🔥 FirebaseException: ${e.code} - ${e.message}");
      _showError(e.message ?? "Firebase hatası: ${e.code}");
    } catch (e, st) {
      debugPrint("🔥 Login error: $e");
      debugPrint("🔥 Stacktrace: $st");
      _showError("Hata: $e");
    }

    _setLoading(false);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
        colors: const [_pinkBtn, _greenBtn, _bgBlue, Color(0xFFE8E0FF)],
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                EntranceAnimation(
                  duration: const Duration(milliseconds: 750),
                  beginOffset: const Offset(0, -0.08),
                  beginScale: 0.88,
                  child: GentleFloat(child: _buildHeader()),
                ),
                const SizedBox(height: 30),
                EntranceAnimation(
                  delay: const Duration(milliseconds: 100),
                  child: _buildWelcomeText(),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Column(
                    children: [
                      EntranceAnimation(
                        delay: const Duration(milliseconds: 180),
                        child: _buildExpandableRoleCard(
                          role: "Anne",
                          color: _pinkBtn,
                          icon: Icons.face_retouching_natural,
                        ),
                      ),
                      const SizedBox(height: 16),
                      EntranceAnimation(
                        delay: const Duration(milliseconds: 260),
                        child: _buildExpandableRoleCard(
                          role: "Üst Kuşak",
                          color: _greenBtn,
                          icon: Icons.face_6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      EntranceAnimation(
                        delay: const Duration(milliseconds: 340),
                        child: _buildExpandableRoleCard(
                          role: "Admin",
                          color: _adminBtn,
                          icon: Icons.admin_panel_settings,
                        ),
                      ),
                    ],
                  ),
                ),
                EntranceAnimation(
                  delay: const Duration(milliseconds: 420),
                  child: _buildFooterInfo(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableRoleCard({
    required String role,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = selectedRole == role;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(25),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                selectedRole = isSelected ? null : role;
              });
            },
            leading: Icon(icon, color: Colors.white),
            title: Text(
              role,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Icon(
              isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isSelected
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTextField(
                          hint: "Telefon",
                          icon: Icons.phone,
                          controller: _phoneController,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          hint: "Şifre",
                          icon: Icons.lock,
                          controller: _passwordController,
                          obscure: true,
                        ),
                        const SizedBox(height: 5),
                        Theme(
                          data: Theme.of(context).copyWith(
                            unselectedWidgetColor: Colors.white,
                            checkboxTheme: CheckboxThemeData(
                              fillColor: WidgetStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return Colors.transparent;
                                },
                              ),
                              checkColor: WidgetStateProperty.all(color),
                              side: const BorderSide(color: Colors.white),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: rememberMe,
                            onChanged: (v) =>
                                setState(() => rememberMe = v ?? false),
                            title: const Text(
                              "Beni hatırla",
                              style: TextStyle(color: Colors.white),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            activeColor: Colors.white,
                            checkColor: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: color,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black54,
                                  ),
                                )
                              : const Text("DEVAM ET"),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildHeader() {
    return Image.asset("assets/foto1.png", width: 180);
  }

  Widget _buildWelcomeText() {
    return const Column(
      children: [
        Text(
          "Hoş geldiniz 🌸",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _textBlue,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Devam etmek için kendinizi tanımlayın:",
          style: TextStyle(fontSize: 14, color: Colors.blueGrey),
        ),
      ],
    );
  }

  Widget _buildFooterInfo() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        "Verilen bilgiler gizli tutulacak ve yalnızca bilimsel amaçlar için kullanılacaktır.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.blueGrey, fontSize: 12),
      ),
    );
  }
}
