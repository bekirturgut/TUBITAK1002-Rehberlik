import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';
import 'GameCardDetailPage.dart';

class GameCardsTab extends StatefulWidget {
  const GameCardsTab({super.key});

  @override
  State<GameCardsTab> createState() => _GameCardsTabState();
}

class _GameCardsTabState extends State<GameCardsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _searchText = "";
  String _selectedGroup = "mother";

  final int _limit = 20;
  bool _isLoading = false;
  bool _hasMore = true;

  DocumentSnapshot? _lastDoc;
  final List<QueryDocumentSnapshot> _cards = [];

  CollectionReference get _activeCardRef {
    return FirebaseFirestore.instance.collection(
      _selectedGroup == "mother" ? "MotherLearnCard" : "UpperLearnCard",
    );
  }

  String get _selectedGroupTitle {
    return _selectedGroup == "mother" ? "Anne Kartları" : "Üst Kuşak Kartları";
  }

  @override
  void initState() {
    super.initState();
    _loadCards();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _loadCards();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCards({bool reset = false}) async {
    if (_isLoading) return;
    if (!_hasMore && !reset) return;

    setState(() => _isLoading = true);

    if (reset) {
      _cards.clear();
      _lastDoc = null;
      _hasMore = true;
    }

    Query query = _activeCardRef
        .orderBy("createdAt", descending: true)
        .limit(_limit);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      _lastDoc = snapshot.docs.last;
      _cards.addAll(snapshot.docs);
    }

    if (snapshot.docs.length < _limit) {
      _hasMore = false;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCards() async {
    await _loadCards(reset: true);
  }

  Future<void> _deleteCard(BuildContext context, String docId) async {
    final confirm = await _confirmDelete(
      context,
      "Bu oyun kartını silmek istediğine emin misin?",
    );

    if (!confirm) return;

    await _activeCardRef.doc(docId).delete();

    _cards.removeWhere((doc) => doc.id == docId);

    if (!mounted) return;
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Kart silindi")),
    );
  }

  void _goDetail(
      BuildContext context, {
        required bool isCreate,
        required String docId,
        required Map<String, dynamic> data,
      }) async {
    final newData = {
      ...data,
      "targetGroup": _selectedGroup,
    };

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameCardDetailPage(
          docId: docId,
          itemData: newData,
          isCreate: isCreate,
        ),
      ),
    );

    _refreshCards();
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchText.trim().isEmpty) return true;

    final q = _searchText.toLowerCase().trim();
    final bilinen = (data["bilinen"] ?? "").toString().toLowerCase();
    final startWeek = (data["startWeek"] ?? "").toString().toLowerCase();

    return bilinen.contains(q) || startWeek.contains(q);
  }

  Widget _buildGroupSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _groupButton("Anne Kartları", "mother")),
          const SizedBox(width: 8),
          Expanded(child: _groupButton("Üst Kuşak", "upper")),
        ],
      ),
    );
  }

  Widget _groupButton(String title, String value) {
    final selected = _selectedGroup == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedGroup = value;
          _searchCtrl.clear();
          _searchText = "";
        });
        _loadCards(reset: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.textBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (value) {
          setState(() => _searchText = value);
        },
        decoration: InputDecoration(
          icon: const Icon(Icons.search, color: AppColors.textBlue),
          hintText: "$_selectedGroupTitle içinde ara...",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _cardItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final bilinen = (data["bilinen"] ?? "").toString();
    final startWeek = data["startWeek"] ?? 1;

    return InkWell(
      onTap: () => _goDetail(
        context,
        isCreate: false,
        docId: doc.id,
        data: data,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.style, color: AppColors.textBlue, size: 20),
            const SizedBox(width: 10),

            Expanded(
              child: Text(
                bilinen,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlue,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgBlue.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$startWeek. hafta",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textBlue,
                  fontWeight: FontWeight.bold,
                ),
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
              icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
            ),

            IconButton(
              tooltip: "Sil",
              onPressed: () => _deleteCard(context, doc.id),
              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCards = _cards.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return _matchesSearch(data);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgBlue,
      body: Column(
        children: [
          _buildGroupSelector(),
          _buildSearchBox(),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCards,
              child: filteredCards.isEmpty && !_isLoading
                  ? Center(
                child: Text(
                  "$_selectedGroupTitle için kart bulunamadı.",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blueGrey,
                  ),
                ),
              )
                  : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: filteredCards.length + 1,
                itemBuilder: (context, index) {
                  if (index == filteredCards.length) {
                    if (!_hasMore) return const SizedBox(height: 20);

                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  return _cardItem(filteredCards[index]);
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
            "targetGroup": _selectedGroup,
            "startWeek": 1,
          },
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Yeni Kart",
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
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Sil"),
        ),
      ],
    ),
  );

  return result ?? false;
}