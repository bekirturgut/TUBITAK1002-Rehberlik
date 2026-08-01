import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';

class GameCardDetailPage extends StatefulWidget {
  final String docId;
  final bool isCreate;
  final Map<String, dynamic> itemData;

  const GameCardDetailPage({
    super.key,
    required this.docId,
    required this.itemData,
    this.isCreate = false,
  });

  @override
  State<GameCardDetailPage> createState() => _GameCardDetailPageState();
}

class _GameCardDetailPageState extends State<GameCardDetailPage> {
  late TextEditingController _bilinenCtrl;
  late TextEditingController _gercekCtrl;
  late TextEditingController _startWeekCtrl;

  String _targetGroup = "mother";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _bilinenCtrl = TextEditingController(
      text: widget.itemData["bilinen"] ?? "",
    );

    _gercekCtrl = TextEditingController(
      text: widget.itemData["gercek"] ?? "",
    );

    _startWeekCtrl = TextEditingController(
      text: (widget.itemData["startWeek"] ?? 1).toString(),
    );

    _targetGroup = widget.itemData["targetGroup"] ?? "mother";
  }

  @override
  void dispose() {
    _bilinenCtrl.dispose();
    _gercekCtrl.dispose();
    _startWeekCtrl.dispose();
    super.dispose();
  }

  String get _collectionName {
    return _targetGroup == "mother"
        ? "MotherLearnCard"
        : "UpperLearnCard";
  }

  Future<void> _saveItem() async {
    final bilinen = _bilinenCtrl.text.trim();
    final gercek = _gercekCtrl.text.trim();
    final startWeek = int.tryParse(_startWeekCtrl.text.trim());

    if (bilinen.isEmpty || gercek.isEmpty) {
      _snack("Bilinen ve gerçek alanları boş bırakılamaz");
      return;
    }

    if (startWeek == null || startWeek < 0) {
      _snack("Başlangıç haftası geçerli olmalıdır");
      return;
    }

    setState(() => _isSaving = true);

    final ref = FirebaseFirestore.instance.collection(_collectionName);

    final data = {
      "bilinen": bilinen,
      "gercek": gercek,
      "startWeek": startWeek,
      "targetGroup": _targetGroup,
      "isActive": widget.itemData["isActive"] ?? true,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    try {
      if (widget.isCreate) {
        await ref.add({
          ...data,
          "createdAt": FieldValue.serverTimestamp(),
        });
        _snack("Kart eklendi");
      } else {
        await ref.doc(widget.docId).update(data);
        _snack("Kart güncellendi");
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

  Widget _groupSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _targetGroup,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.group, color: AppColors.textBlue),
        filled: true,
        fillColor: AppColors.bgBlue.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: "mother",
          child: Text("Anne Kartı"),
        ),
        DropdownMenuItem(
          value: "upper",
          child: Text("Üst Kuşak Kartı"),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _targetGroup = value;
        });
      },
    );
  }

  Widget _modernField(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        int maxLines = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.4,
          ),
        )
            : Text(
          widget.isCreate ? "KARTI EKLE" : "GÜNCELLE",
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

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          widget.isCreate ? "Yeni Öğrenme Kartı 🃏" : "Öğrenme Kartını Düzenle 🃏",
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlue,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          "Kart hedef grubunu ve görünmeye başlayacağı haftayı seçebilirsiniz",
          style: TextStyle(color: Colors.blueGrey),
          textAlign: TextAlign.center,
        ),
      ],
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
          _groupSelector(),
          const SizedBox(height: 14),

          _modernField(
            _startWeekCtrl,
            "Kaçıncı haftadan sonra görünsün?",
            Icons.calendar_month,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),

          _modernField(_bilinenCtrl, "Bilinen", Icons.lightbulb, maxLines: 4),
          const SizedBox(height: 14),

          _modernField(_gercekCtrl, "Gerçek", Icons.fact_check, maxLines: 6),
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