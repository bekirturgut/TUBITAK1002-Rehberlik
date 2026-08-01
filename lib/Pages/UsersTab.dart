import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'ChatPage.dart';
import 'UserDetailPage.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _q = "";

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _deleteUserCascade(String userId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await _deleteSubcollection(userRef.collection('notifications'));
    await _deleteSubcollection(userRef.collection('loginHistory'));
    await _deleteSubcollection(userRef.collection('scheduledNotifs'));

    await userRef.delete();
  }

  Future<void> _deleteSubcollection(CollectionReference colRef) async {
    const int batchSize = 200;

    while (true) {
      final snapshot = await colRef.limit(batchSize).get();

      if (snapshot.docs.isEmpty) break;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    }
  }

  Future<void> _confirmAndDeleteUser(String userId, String fullName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kullanıcı silinsin mi?"),
        content: Text(
          "$fullName adlı kullanıcı silinecek.\n"
              "Bildirimler ve giriş geçmişi de tamamen kaldırılacak.\n\n"
              "Bu işlem geri alınamaz.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Sil",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _deleteUserCascade(userId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$fullName silindi")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Silme sırasında hata oluştu: $e")),
      );
    }
  }

  bool _matches(Map<String, dynamic> user) {
    if (_q.isEmpty) return true;

    final name = (user["name"] ?? "").toString().toLowerCase();
    final surname = (user["surname"] ?? "").toString().toLowerCase();
    final phone = (user["phone"] ?? "").toString().toLowerCase();

    return name.contains(_q) || surname.contains(_q) || phone.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("chats")
                    .where("hasPendingAdminReply", isEqualTo: true)
                    .snapshots(),
                builder: (context, pendingSnapshot) {
                  if (pendingSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final pendingDocs = pendingSnapshot.data?.docs ?? [];
                  final pendingUserIds = pendingDocs.map((d) => d.id).toSet();

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      final filteredDocs = docs.where((d) {
                        final user = d.data() as Map<String, dynamic>;
                        return _matches(user);
                      }).toList();

                      final annes = filteredDocs
                          .where((d) => d["role"] == "Anne")
                          .toList();
                      final ust = filteredDocs
                          .where((d) => d["role"] == "Üst Kuşak")
                          .toList();
                      final admins = filteredDocs
                          .where((d) => d["role"] == "Admin")
                          .toList();

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatCard(
                              filteredDocs.length,
                              pendingUserIds.length,
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              context,
                              "Uzmanlar",
                              admins,
                              Colors.deepPurple,
                              pendingUserIds,
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              context,
                              "Anneler",
                              annes,
                              AppColors.pinkBtn,
                              pendingUserIds,
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              context,
                              "Üst Kuşak",
                              ust,
                              AppColors.greenBtn,
                              pendingUserIds,
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.textBlue,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Kullanıcı Ekle",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserDetailPage(
                    userId: "",
                    userData: {},
                    isCreate: true,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      key: const ValueKey("users_search"),
      controller: _searchCtrl,
      focusNode: _searchFocus,
      onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: "İsim / Soyisim / Telefon ara...",
        prefixIcon: const Icon(Icons.search, color: AppColors.textBlue),
        suffixIcon: _q.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.clear, color: AppColors.textBlue),
          onPressed: () {
            _searchCtrl.clear();
            setState(() => _q = "");
            _searchFocus.requestFocus();
          },
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildStatCard(int count, int pendingCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.learnStart, AppColors.learnEnd],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_alt_rounded,
            color: AppColors.textBlue,
            size: 40,
          ),
          const SizedBox(height: 10),
          const Text(
            "Toplam Üye",
            style: TextStyle(color: AppColors.textBlue),
          ),
          Text(
            "$count",
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlue,
            ),
          ),
          const SizedBox(height: 10),
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                "$pendingCount kullanıcıda cevap bekleyen soru var",
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      List<QueryDocumentSnapshot> users,
      Color color,
      Set<String> pendingUserIds,
      ) {
    if (users.isEmpty) {
      if (_q.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            "$title için sonuç yok.",
            style: const TextStyle(color: Colors.blueGrey),
          ),
        );
      }
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textBlue,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, i) {
            final user = users[i].data() as Map<String, dynamic>;
            final id = users[i].id;
            final fullName =
            "${user["name"] ?? ""} ${user["surname"] ?? ""}".trim();
            final hasPending = pendingUserIds.contains(id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: hasPending
                    ? Border.all(color: Colors.red.shade200, width: 1.2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: hasPending
                      ? LinearGradient(
                    colors: [
                      Colors.red.shade50,
                      Colors.white,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                      : null,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.person,
                      color: color,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.priority_high,
                                size: 14,
                                color: Colors.red.shade800,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Yanıt Bekliyor",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user["phone"] ?? "-",
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (hasPending)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.support_agent,
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    "Bot cevaplayamadı, uzman yanıtı bekleniyor.",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user["role"] != "Admin")
                        Container(
                          decoration: BoxDecoration(
                            color: hasPending
                                ? Colors.red.shade100
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              hasPending
                                  ? Icons.support_agent
                                  : Icons.chat_bubble_outline,
                              color: hasPending
                                  ? Colors.red.shade700
                                  : Colors.blueAccent,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    userId: id,
                                    selectedRole: "Admin",
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(width: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            _confirmAndDeleteUser(
                              id,
                              fullName.isEmpty ? "Kullanıcı" : fullName,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailPage(
                          userId: id,
                          userData: user,
                          isCreate: false,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}