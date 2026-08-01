import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'ChatbotDetailPage.dart';

class ChatbotTab extends StatefulWidget {
  const ChatbotTab({super.key});

  @override
  State<ChatbotTab> createState() => _ChatbotTabState();
}

class _ChatbotTabState extends State<ChatbotTab> {
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchText = "";
  String _statusFilter = "all"; // all, active, passive

  CollectionReference get _faqRef =>
      FirebaseFirestore.instance.collection("faq_items");

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteItem(BuildContext context, String docId) async {
    final confirm = await _confirmDelete(
      context,
      "Bu chatbot kaydını silmek istediğine emin misin?",
    );

    if (!confirm) return;

    await _faqRef.doc(docId).delete();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Chatbot verisi silindi")),
    );
  }

  Future<void> _toggleActive(
      BuildContext context,
      String docId,
      bool currentValue,
      ) async {
    await _faqRef.doc(docId).update({
      "isActive": !currentValue,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentValue ? "Kayıt aktif edildi" : "Kayıt pasif yapıldı",
        ),
      ),
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
        builder: (_) => ChatbotDetailPage(
          docId: docId,
          itemData: data,
          isCreate: isCreate,
        ),
      ),
    );
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchText.trim().isEmpty) return true;

    final q = _searchText.toLowerCase().trim();
    final question = (data["question"] ?? "").toString().toLowerCase();
    final answer = (data["answer"] ?? "").toString().toLowerCase();

    return question.contains(q) || answer.contains(q);
  }

  bool _matchesStatus(Map<String, dynamic> data) {
    final isActive = data["isActive"] == true;

    if (_statusFilter == "active") {
      return isActive;
    }

    if (_statusFilter == "passive") {
      return !isActive;
    }

    return true;
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
          hintText: "Soru veya cevap içinde ara...",
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

  Widget _buildStatusFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(6),
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
      child: Row(
        children: [
          Expanded(
            child: _filterButton(
              title: "Tümü",
              value: "all",
              color: AppColors.textBlue,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              title: "Aktifler",
              value: "active",
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              title: "Pasifler",
              value: "passive",
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required String title,
    required String value,
    required Color color,
  }) {
    final selected = _statusFilter == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlue,
      body: Column(
        children: [
          _buildSearchBox(),
          _buildStatusFilter(),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _faqRef.orderBy("createdAt", descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Hata: ${snapshot.error}"));
                }

                final allDocs = snapshot.data?.docs ?? [];

                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return _matchesSearch(data) && _matchesStatus(data);
                }).toList();

                if (allDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Henüz chatbot verisi eklenmedi.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  );
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Seçilen filtreye uygun chatbot verisi bulunamadı.",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final question = (data["question"] ?? "").toString();
                    final answer = (data["answer"] ?? "").toString();
                    final isActive = data["isActive"] == true;

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
                                    Icons.smart_toy,
                                    color: AppColors.textBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                      const SizedBox(height: 6),
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
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isActive ? "Aktif" : "Pasif",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: isActive ? "Pasif yap" : "Aktif yap",
                                  onPressed: () =>
                                      _toggleActive(context, doc.id, isActive),
                                  icon: Icon(
                                    isActive
                                        ? Icons.toggle_on
                                        : Icons.toggle_off,
                                    color: isActive ? Colors.green : Colors.grey,
                                    size: 28,
                                  ),
                                ),
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
                                    color: Colors.blue,
                                    size: 22,
                                  ),
                                ),
                                IconButton(
                                  tooltip: "Sil",
                                  onPressed: () => _deleteItem(context, doc.id),
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
          "Yeni Kayıt",
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