import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'package:flutter/services.dart';

class NotificationDetailPage extends StatefulWidget {
  final String docId;
  final bool isCreate;
  final Map<String, dynamic> itemData;

  const NotificationDetailPage({
    super.key,
    required this.docId,
    required this.itemData,
    this.isCreate = false,
  });

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  late TextEditingController _delayCtrl;

  String _selectedRole = "Anne";
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.itemData["title"] ?? "",
    );
    _bodyCtrl = TextEditingController(
      text: widget.itemData["body"] ?? "",
    );
    _delayCtrl = TextEditingController(
      text: (widget.itemData["delayDays"] ?? 0).toString(),
    );

    _selectedRole = (widget.itemData["targetRole"] ?? "Anne").toString();
    _isActive = widget.isCreate ? true : (widget.itemData["isActive"] == true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _delayCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final delayDays = int.tryParse(_delayCtrl.text.trim()) ?? -1;

    if (title.isEmpty || body.isEmpty) {
      _snack("Başlık ve mesaj boş bırakılamaz");
      return;
    }

    if (delayDays < 0) {
      _snack("Gün sayısı 0 veya daha büyük olmalı");
      return;
    }

    setState(() => _isSaving = true);

    final ref = FirebaseFirestore.instance.collection("notifications");

    final data = {
      "title": title,
      "body": body,
      "targetRole": _selectedRole,
      "delayDays": delayDays,
      "isActive": _isActive,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      if (widget.isCreate) {
        await ref.add({
          ...data,
          "createdAt": FieldValue.serverTimestamp(),
        });
        _snack("Bildirim eklendi");
      } else {
        await ref.doc(widget.docId).update(data);
        _snack("Bildirim güncellendi");
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _snack("İşlem başarısız: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    if (ts is! Timestamp) return "-";
    final date = ts.toDate();
    return "${date.day.toString().padLeft(2, '0')}."
        "${date.month.toString().padLeft(2, '0')}."
        "${date.year}  "
        "${date.hour.toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.isCreate ? "Yeni Bildirim Ekle 🔔" : "Bildirimi Düzenle 🔔",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.isCreate
              ? "Anne veya Üst Kuşak için yeni bildirim ekleyebilirsiniz"
              : "Bildirim bilgisini güncelleyebilirsiniz",
          style: const TextStyle(color: Colors.blueGrey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _modernField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        int maxLines = 1,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.textBlue)
            : Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(icon, color: AppColors.textBlue),
        ),
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

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.group, color: AppColors.textBlue),
        hintText: "Hedef Kitle",
        filled: true,
        fillColor: AppColors.bgBlue.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      items: const [
        DropdownMenuItem(value: "Anne", child: Text("Anne")),
        DropdownMenuItem(value: "Üst Kuşak", child: Text("Üst Kuşak")),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() => _selectedRole = v);
      },
    );
  }

  Widget _buildMetaInfo() {
    final created = widget.itemData["createdAt"];
    final updated = widget.itemData["updatedAt"];

    if (widget.isCreate) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 18),
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
              Expanded(
                child: Text(
                  "Oluşturulma: ${_formatDate(created)}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.update, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Son Güncelleme: ${_formatDate(updated)}",
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.greenBtn,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.4,
          ),
        )
            : Text(
          widget.isCreate ? "BİLDİRİMİ EKLE" : "GÜNCELLE",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pinkBtn,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          "GERİ DÖN",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

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
          ),
        ],
      ),
      child: Column(
        children: [
          _buildRoleDropdown(),
          const SizedBox(height: 14),
          _modernField(
            _delayCtrl,
            "Kaç gün sonra gözüksün? (ör: 7)",
            Icons.schedule,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          const SizedBox(height: 14),
          _modernField(_titleCtrl, "Başlık", Icons.title),
          const SizedBox(height: 14),
          _modernField(_bodyCtrl, "Mesaj", Icons.message, maxLines: 6),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgBlue.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Aktif mi?"),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ),
          _buildMetaInfo(),
          const SizedBox(height: 16),
          _saveButton(),
          const SizedBox(height: 10),
          _backButton(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlue,
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
}