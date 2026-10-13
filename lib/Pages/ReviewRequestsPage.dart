import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ChatPage.dart';

class ReviewRequestsPage extends StatelessWidget {
  const ReviewRequestsPage({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler ve veri talepleri'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'İçerik bildirimleri'),
            Tab(text: 'Silme talepleri'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _requests(context, 'content_reports', false),
          _requests(context, 'deletion_requests', true),
        ],
      ),
    ),
  );

  Widget _requests(
    BuildContext context,
    String collection,
    bool deletion,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection(collection).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Talepler yüklenemedi.'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList()
        ..sort((a, b) {
          final at = a.data()['createdAt'] as Timestamp?;
          final bt = b.data()['createdAt'] as Timestamp?;
          return (bt?.millisecondsSinceEpoch ?? 0).compareTo(
            at?.millisecondsSinceEpoch ?? 0,
          );
        });
      if (docs.isEmpty) return const Center(child: Text('Henüz talep yok.'));
      return ListView(
        children: [
          if (deletion)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Kimliği doğrulayın ve Üyeler bölümünden hesabı, sohbeti ve ilişkili verileri silin. Talebi yalnızca silme işlemi tamamlandıktan sonra sonuçlandırın.',
              ),
            ),
          for (final doc in docs)
            ListTile(
              title: Text(
                deletion
                    ? 'Hesap ve veri silme talebi'
                    : doc.data()['reason']?.toString() ?? 'İçerik bildirimi',
              ),
              subtitle: Text(
                'Kullanıcı: ${doc.data()['userId']} · '
                '${doc.data()['status'] == 'pending' ? 'Bekliyor' : 'İncelendi'}',
              ),
              onTap: deletion
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          userId: doc.data()['userId'].toString(),
                          selectedRole: 'Admin',
                        ),
                      ),
                    ),
              trailing: doc.data()['status'] != 'pending'
                  ? null
                  : IconButton(
                      tooltip: 'İncelemeyi tamamla',
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: deletion
                          ? null
                          : () async {
                              await doc.reference.update({
                                'status': 'reviewed',
                                'reviewedAt': FieldValue.serverTimestamp(),
                              });
                            },
                    ),
            ),
        ],
      );
    },
  );
}
