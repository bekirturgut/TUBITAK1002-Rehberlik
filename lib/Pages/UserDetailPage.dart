import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tubitak/Pages/AdminPage.dart';
import '../constants.dart';
import 'LoginHistoryPage.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  final bool isCreate;
  final Map<String, dynamic> userData;

  const UserDetailPage({
    super.key,
    required this.userId,
    required this.userData,
    this.isCreate = false,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _surnameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passwordCtrl;

  String? _selectedRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userData["name"] ?? "");
    _surnameCtrl = TextEditingController(text: widget.userData["surname"] ?? "");
    _phoneCtrl = TextEditingController(text: widget.userData["phone"] ?? "");
    _passwordCtrl = TextEditingController();
    _selectedRole = widget.userData["role"];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  //EKLE + GÜNCELLE
  Future<void> _saveUser() async {
    if (_selectedRole == null) {
      _snack("Rol seçiniz");
      return;
    }

    setState(() => _isSaving = true);
    final normalizedPhone = _normalizePhone(_phoneCtrl.text.trim());
    final data = {
      "name": _nameCtrl.text.trim(),
      "surname": _surnameCtrl.text.trim(),
      "phone": normalizedPhone,
      "role": _selectedRole,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (_passwordCtrl.text.trim().isNotEmpty) {
      data["password"] = _passwordCtrl.text.trim();
    }

    final ref = FirebaseFirestore.instance.collection("users");

    if (widget.isCreate) {
      data["createdAt"] = FieldValue.serverTimestamp();
      await ref.add(data);
      _snack("Kullanıcı eklendi");
    } else {
      await ref.doc(widget.userId).update(data);
      _snack("Kullanıcı güncellendi");
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //HEADER
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.isCreate ? "Yeni Kullanıcı 👤" : "Kullanıcı Düzenle 👤",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlue,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isCreate
              ? "Yeni kullanıcı oluşturabilirsiniz"
              : "Bilgileri güncelleyebilirsiniz",
          style: const TextStyle(color: Colors.blueGrey),
        ),
      ],
    );
  }

  //ANA KART
  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
        children: [
          _modernField(_nameCtrl, "İsim", Icons.person),
          const SizedBox(height: 14),
          _modernField(_surnameCtrl, "Soyisim", Icons.badge),
          const SizedBox(height: 14),
          _modernField(_phoneCtrl, "Telefon", Icons.phone,
              keyboard: TextInputType.phone),
          const SizedBox(height: 14),

          _modernField(
            _passwordCtrl,
            widget.isCreate
                ? "Şifre"
                : "Yeni Şifre (opsiyonel)",
            Icons.lock,
            obscure: true,
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.bgBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                border: InputBorder.none,
                labelText: "Rol",
              ),
              items: const [
                DropdownMenuItem(value: "Anne", child: Text("Anne")),
                DropdownMenuItem(value: "Üst Kuşak", child: Text("Üst Kuşak")),
                DropdownMenuItem(value: "Admin", child: Text("Uzman")),
              ],
              onChanged: (val) => setState(() => _selectedRole = val),
            ),
          ),

          const SizedBox(height: 10),
          if (!widget.isCreate) _buildMetaInfo(),
          const SizedBox(height: 10),
          if (!widget.isCreate) _loginHistoryButton(),
          const SizedBox(height: 10),
          _saveButton(),
          const SizedBox(height: 10),
          _OutButton(),
        ],
      ),
    );
  }

  Widget _modernField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType keyboard = TextInputType.text,
        bool obscure = false,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textBlue),
        hintText: hint,
        filled: true,
        fillColor: AppColors.bgBlue.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  //SAVE BUTTON
  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.greenBtn,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          widget.isCreate ? "KULLANICI EKLE" : "GÜNCELLE",
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _OutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AdminPage()),
                (route) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pinkBtn,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          "ÇIKIŞ",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
  Widget _buildMetaInfo() {
    final created = widget.userData["createdAt"];
    final updated = widget.userData["updatedAt"];

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "Oluşturulma: ${_formatDate(created)}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.update, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "Son Güncelleme: ${_formatDate(updated)}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
  String _normalizePhone(String input) {
    String phone = input.replaceAll(RegExp(r'\s+'), '');

    // +90 varsa koru
    if (phone.startsWith('+90')) return phone;

    // 0090 → +90
    if (phone.startsWith('0090')) {
      return '+90${phone.substring(4)}';
    }

    // 0 ile başlıyorsa sil
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    // Direkt 5 ile başlıyorsa
    if (phone.startsWith('5')) {
      return '+90$phone';
    }

    return '+90$phone'; // fallback
  }


  //DATE FORMAT
  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    final date = (ts as Timestamp).toDate();
    return "${date.day.toString().padLeft(2, '0')}."
        "${date.month.toString().padLeft(2, '0')}."
        "${date.year}  "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _loginHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LoginHistoryPage(userId: widget.userId),
            ),
          );
        },
        icon: const Icon(Icons.history),
        label: const Text(
          "GİRİŞ GEÇMİŞİ",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgBlue,
          foregroundColor: AppColors.textBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
