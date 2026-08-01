import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import 'NotificationDetailPage.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({super.key});

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _searchText = "";
  String _selectedRole = "Anne";

  CollectionReference get _notifRef =>
      FirebaseFirestore.instance.collection("notifications");

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _deleteNotification(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text("Bildirimi sil"),
        content: const Text("Bu bildirimi silmek istediğine emin misin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _notifRef.doc(docId).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bildirim silindi")),
    );
  }

  Future<void> _toggleActive(
      BuildContext context,
      String docId,
      bool currentValue,
      ) async {
    await _notifRef.doc(docId).update({
      "isActive": !currentValue,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !currentValue ? "Bildirim aktif edildi" : "Bildirim pasif yapıldı",
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
        builder: (_) => NotificationDetailPage(
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
    final title = (data["title"] ?? "").toString().toLowerCase();
    final body = (data["body"] ?? "").toString().toLowerCase();
    final role = (data["targetRole"] ?? "").toString().toLowerCase();

    return title.contains(q) || body.contains(q) || role.contains(q);
  }

  Widget _buildRoleSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
            child: _roleButton(
              title: "Anneler",
              value: "Anne",
              color: AppColors.pinkBtn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _roleButton(
              title: "Üst Kuşak",
              value: "Üst Kuşak",
              color: AppColors.greenBtn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleButton({
    required String title,
    required String value,
    required Color color,
  }) {
    final selected = _selectedRole == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedRole = value;
          _searchCtrl.clear();
          _searchText = "";
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
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
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() => _searchText = value);
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: AppColors.textBlue),
          hintText: "$_selectedRole bildirimlerinde ara...",
          border: InputBorder.none,
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchText = "");
              _searchFocus.requestFocus();
            },
            icon: const Icon(Icons.close, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _notifCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final title = (data["title"] ?? "").toString();
    final body = (data["body"] ?? "").toString();
    final role = (data["targetRole"] ?? "-").toString();
    final createdAt = _formatDate(data["createdAt"]);
    final isActive = data["isActive"] == true;
    final delayDays = data["delayDays"] ?? 0;

    final chipColor = role == "Anne" ? AppColors.pinkBtn : AppColors.greenBtn;

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
                    Icons.notifications_active,
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textBlue,
                              ),
                            ),
                          ),
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "$delayDays gün sonra",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        createdAt,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: isActive ? "Pasif yap" : "Aktif yap",
                  onPressed: () => _toggleActive(context, doc.id, isActive),
                  icon: Icon(
                    isActive ? Icons.toggle_on : Icons.toggle_off,
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
                  onPressed: () => _deleteNotification(context, doc.id),
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
    final query = _notifRef.orderBy("createdAt", descending: true);

    return Scaffold(
      backgroundColor: AppColors.bgBlue,
      body: Column(
        children: [
          _buildRoleSelector(),
          _buildSearchBox(),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

                  if (allDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Henüz bildirim eklenmedi.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                    );
                  }

                  final filteredDocs = allDocs.where((d) {
                    final m = d.data() as Map<String, dynamic>;
                    final role = (m["targetRole"] ?? "").toString();

                    return role == _selectedRole && _matchesSearch(m);
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        "$_selectedRole için bildirim bulunamadı.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.blueGrey,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      return _notifCard(context, filteredDocs[index]);
                    },
                  );
                },
              ),
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
          data: {
            "targetRole": _selectedRole,
          },
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni Bildirim",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}