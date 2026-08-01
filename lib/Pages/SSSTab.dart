import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'SSSDetailPage.dart';

class SSSTab extends StatefulWidget {
  const SSSTab({super.key});

  @override
  State<SSSTab> createState() => _SSSTabState();
}

class _SSSTabState extends State<SSSTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = "";

  CollectionReference get _sssRef =>
      FirebaseFirestore.instance.collection("sss");

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteFAQ(BuildContext context, String docId) async {
    final confirm = await _confirmDelete(
      context,
      "Bu SSS kaydını silmek istediğine emin misin?",
    );

    if (!confirm) return;

    await _sssRef.doc(docId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("SSS kaydı silindi")),
    );
  }

  void _goDetail(
      BuildContext context, {
        required bool isCreate,
        required String docId,
        required Map<String, dynamic> data,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SSSDetailPage(
          docId: docId,
          itemData: data,
          isCreate: isCreate,
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return "-";
    if (ts is! Timestamp) return "-";
    final d = ts.toDate();
    return "${d.day.toString().padLeft(2, '0')}."
        "${d.month.toString().padLeft(2, '0')}."
        "${d.year} "
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchText.trim().isEmpty) return true;

    final q = _searchText.toLowerCase().trim();
    final question = (data["question"] ?? "").toString().toLowerCase();
    final answer = (data["answer"] ?? "").toString().toLowerCase();

    return question.contains(q) || answer.contains(q);
  }

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() => _searchText = value);
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: AppColors.textBlue),
          hintText: "SSS içinde ara...",
          border: InputBorder.none,
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchText = "");
            },
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _faqCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final question = (data["question"] ?? "").toString();
    final answer = (data["answer"] ?? "").toString();
    final updatedAt = _formatDate(data["updatedAt"] ?? data["createdAt"]);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _goDetail(
        context,
        isCreate: false,
        docId: doc.id,
        data: data,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.help_outline,
                    color: AppColors.textBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        answer,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Detay için karta dokun",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Son güncelleme: $updatedAt",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: "Düzenle",
                  onPressed: () => _goDetail(
                    context,
                    isCreate: false,
                    docId: doc.id,
                    data: data,
                  ),
                  icon: const Icon(
                    Icons.edit,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
                IconButton(
                  tooltip: "Sil",
                  onPressed: () => _deleteFAQ(context, doc.id),
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _sssRef.orderBy("updatedAt", descending: true);

    return Scaffold(
      backgroundColor: AppColors.bgBlue,
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(child: Text("Hata: ${snap.error}"));
                }

                final allDocs = snap.data?.docs ?? [];
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _matchesSearch(data);
                }).toList();

                if (allDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Henüz SSS eklenmedi.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  );
                }

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Aramaya uygun SSS bulunamadı.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    return _faqCard(context, filteredDocs[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textBlue,
        onPressed: () => _goDetail(
          context,
          isCreate: true,
          docId: "",
          data: const {},
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni SSS",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      title: const Text("Silme Onayı"),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Vazgeç"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Sil"),
        ),
      ],
    ),
  );

  return result ?? false;
}