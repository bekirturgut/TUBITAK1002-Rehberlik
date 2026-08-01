import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/quiz_progress_service.dart';
import '../widgets/app_animations.dart';

enum QuizMode { normal, wrongAnswers }

class _QuizCard {
  final String id;
  final String collectionName;
  final String question;
  final String answer;
  final List<String> options;

  const _QuizCard({
    required this.id,
    required this.collectionName,
    required this.question,
    required this.answer,
    required this.options,
  });
}

class LearnPage extends StatefulWidget {
  final String userId;

  const LearnPage({super.key, required this.userId});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  static const _textBlue = Color(0xFF2C4E7F);
  static const _letters = ['A', 'B', 'C', 'D'];

  bool _loading = true;
  String? _error;
  String _collectionName = '';
  int _currentWeek = 1;
  int _wrongCount = 0;
  Set<String> _wrongCardIds = {};
  List<_QuizCard> _allCards = [];
  List<_QuizCard> _sessionCards = [];
  QuizMode? _mode;
  int _currentIndex = 0;
  bool _showOptions = false;
  String? _selectedOption;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      final userDoc = await userRef.get();
      if (!userDoc.exists) throw Exception('Kullanıcı bulunamadı');

      final userData = userDoc.data()!;
      _currentWeek = _calculateCurrentWeek(userData);
      _collectionName = _getCollectionName((userData['role'] ?? '').toString());

      final results = await Future.wait([
        FirebaseFirestore.instance.collection(_collectionName).get(),
        userRef.collection('wrongCards').get(),
      ]);
      final cardSnapshot = results[0];
      final wrongSnapshot = results[1];

      final rawCards = <({String id, String question, String answer})>[];
      for (final doc in cardSnapshot.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final startWeek = _asInt(data['startWeek'], fallback: 1);
        if (startWeek > _currentWeek) continue;
        final question = (data['bilinen'] ?? '').toString().trim();
        final answer = (data['gercek'] ?? '').toString().trim();
        if (question.isEmpty || answer.isEmpty) continue;
        rawCards.add((id: doc.id, question: question, answer: answer));
      }

      final uniqueAnswers = rawCards
          .map((card) => card.answer)
          .toSet()
          .toList();
      final random = Random();
      final cards = rawCards.map((card) {
        final distractors =
            uniqueAnswers.where((answer) => answer != card.answer).toList()
              ..shuffle(random);
        final options = <String>[card.answer, ...distractors.take(3)]
          ..shuffle(random);
        return _QuizCard(
          id: card.id,
          collectionName: _collectionName,
          question: card.question,
          answer: card.answer,
          options: options,
        );
      }).toList()..shuffle(random);

      final validWrongIds = wrongSnapshot.docs
          .where((doc) => doc.data()['collectionName'] == _collectionName)
          .map((doc) => (doc.data()['cardId'] ?? '').toString())
          .where(rawCards.map((card) => card.id).toSet().contains)
          .toSet();

      if (!mounted) return;
      setState(() {
        _allCards = cards;
        _wrongCount = validWrongIds.length;
        _wrongCardIds = validWrongIds;
        _loading = false;
      });
      await QuizProgressService.refreshStats(
        userId: widget.userId,
        assignedCount: cards.length,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _startMode(QuizMode mode) async {
    if (_allCards.length < 4 ||
        _allCards.any((card) => card.options.length < 4)) {
      _snack(
        'Dört şık oluşturmak için en az 4 farklı cevaplı aktif kart gerekir.',
      );
      return;
    }

    var selected = List<_QuizCard>.from(_allCards);
    if (mode == QuizMode.wrongAnswers) {
      final wrongSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wrongCards')
          .where('collectionName', isEqualTo: _collectionName)
          .get();
      final ids = wrongSnapshot.docs
          .map((doc) => (doc.data()['cardId'] ?? '').toString())
          .toSet();
      selected = selected.where((card) => ids.contains(card.id)).toList();
      if (selected.isEmpty) {
        _snack('Tekrar çözülecek yanlış soru bulunmuyor.');
        return;
      }
    }

    selected.shuffle();
    setState(() {
      _mode = mode;
      _sessionCards = selected;
      _currentIndex = 0;
      _showOptions = false;
      _selectedOption = null;
    });
  }

  Future<void> _selectOption(String option) async {
    if (_selectedOption != null || _saving) return;
    final card = _sessionCards[_currentIndex];
    final isCorrect = option == card.answer;
    setState(() {
      _selectedOption = option;
      _saving = true;
    });

    try {
      await QuizProgressService.recordAnswer(
        userId: widget.userId,
        cardId: card.id,
        collectionName: card.collectionName,
        question: card.question,
        answer: card.answer,
        isCorrect: isCorrect,
        assignedCount: _allCards.length,
      );
      if (_mode == QuizMode.wrongAnswers && isCorrect) {
        _wrongCardIds.remove(card.id);
        _wrongCount = max(0, _wrongCount - 1);
      } else if (!isCorrect && _wrongCardIds.add(card.id)) {
        _wrongCount++;
      }
    } catch (error) {
      _snack('Cevap kaydedilemedi: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _nextCard() {
    if (_currentIndex + 1 >= _sessionCards.length) {
      setState(() {
        _mode = null;
        _sessionCards = [];
      });
      _snack('Tur tamamlandı. Sonuçlarınız kaydedildi.');
      return;
    }
    setState(() {
      _currentIndex++;
      _showOptions = false;
      _selectedOption = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textBlue),
          onPressed: () {
            if (_mode != null) {
              setState(() => _mode = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _mode == QuizMode.wrongAnswers ? 'Yanlış Sorular' : 'Oyun Kartları',
          style: const TextStyle(color: _textBlue, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: AnimatedPastelBackground(
        colors: const [
          Color(0xFFFFE3EC),
          Color(0xFFDFF2FF),
          Color(0xFFFFF2C9),
          Color(0xFFEDE7FF),
        ],
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!),
                ),
              )
            : _mode == null
            ? _buildModeSelection()
            : _buildQuiz(),
      ),
    );
  }

  Widget _buildModeSelection() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE3EC), Color(0xFFDFF2FF)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Icon(Icons.quiz_rounded, size: 48, color: _textBlue),
              const SizedBox(height: 10),
              const Text(
                'Bilgini test et!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_currentWeek. haftaya kadar tanımlanan ${_allCards.length} soru bulunuyor. Kartı çevir ve doğru cevabı seç.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueGrey, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        EntranceAnimation(
          delay: const Duration(milliseconds: 100),
          child: _modeCard(
            title: 'Normal Sorular',
            subtitle: 'Tanımlı tüm soruları karışık sırada çöz.',
            icon: Icons.style_rounded,
            colors: const [Color(0xFFDFF2FF), Color(0xFFBDE3FF)],
            onTap: () => _startMode(QuizMode.normal),
          ),
        ),
        const SizedBox(height: 16),
        EntranceAnimation(
          delay: const Duration(milliseconds: 190),
          child: _modeCard(
            title: 'Önceden Yanlış Bildiklerim',
            subtitle: _wrongCount == 0
                ? 'Şu anda tekrar edilecek soru yok.'
                : '$_wrongCount yanlış soruyu yeniden çöz.',
            icon: Icons.replay_circle_filled_rounded,
            colors: const [Color(0xFFFFE8D9), Color(0xFFFFD1D1)],
            onTap: () => _startMode(QuizMode.wrongAnswers),
          ),
        ),
      ],
    );
  }

  Widget _modeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, size: 44, color: _textBlue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _textBlue,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textBlue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final card = _sessionCards[_currentIndex];
    final progress = (_currentIndex + 1) / _sessionCards.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 14),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                borderRadius: BorderRadius.circular(99),
              ),
              const SizedBox(height: 7),
              Text(
                '${_currentIndex + 1} / ${_sessionCards.length}',
                style: const TextStyle(
                  color: _textBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            // easeOutBack kısa süreliğine 1.0'ın üzerine çıkar. Bu değer
            // FadeTransition ve içteki CurvedAnimation tarafından kabul
            // edilmediği için kart çevrilirken assertion oluşuyordu.
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final rotate = Tween<double>(begin: pi / 2, end: 0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return AnimatedBuilder(
                animation: rotate,
                child: child,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(rotate.value),
                      child: child,
                    ),
                  );
                },
              );
            },
            child: _showOptions ? _buildBack(card) : _buildFront(card),
          ),
        ),
      ],
    );
  }

  Widget _buildFront(_QuizCard card) {
    return GestureDetector(
      key: ValueKey('front_${card.id}'),
      onTap: () => setState(() => _showOptions = true),
      child: Container(
        margin: const EdgeInsets.fromLTRB(26, 10, 26, 30),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE1EA), Color(0xFFFFF2CC)],
          ),
          borderRadius: BorderRadius.circular(34),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Chip(label: Text('Soru')),
                Spacer(),
                Icon(Icons.flip_to_back_rounded, color: _textBlue),
              ],
            ),
            const Spacer(),
            Text(
              card.question,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                height: 1.35,
                fontWeight: FontWeight.bold,
                color: _textBlue,
              ),
            ),
            const Spacer(),
            const Text(
              'Şıkları görmek için karta dokun',
              style: TextStyle(
                color: Colors.blueGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(_QuizCard card) {
    final answered = _selectedOption != null;
    return Container(
      key: ValueKey('back_${card.id}'),
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDFF3FF), Color(0xFFEDE7FF)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Text(
            card.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textBlue,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: card.options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) => EntranceAnimation(
                delay: Duration(milliseconds: 55 * index),
                duration: const Duration(milliseconds: 360),
                beginOffset: const Offset(0.08, 0),
                child: _optionTile(card, card.options[index], index),
              ),
            ),
          ),
          if (_saving) const LinearProgressIndicator(),
          if (answered && !_saving) ...[
            const SizedBox(height: 8),
            Text(
              _selectedOption == card.answer
                  ? 'Doğru bildiniz! 🎉'
                  : 'Yanlış. Doğru cevap yeşil ile gösterildi.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _selectedOption == card.answer
                    ? Colors.green.shade800
                    : Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _nextCard,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _currentIndex + 1 == _sessionCards.length
                    ? 'Turu Bitir'
                    : 'Sonraki Soru',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(_QuizCard card, String option, int index) {
    final answered = _selectedOption != null;
    final isCorrect = option == card.answer;
    final isSelected = option == _selectedOption;
    Color color = Colors.white;
    if (answered && isCorrect) color = Colors.green.shade100;
    if (answered && isSelected && !isCorrect) color = Colors.red.shade100;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: answered ? null : () => _selectOption(option),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _textBlue,
                child: Text(
                  _letters[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: const TextStyle(
                    color: _textBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (answered && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green),
              if (answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  String _getCollectionName(String role) {
    final normalized = role.toLowerCase();
    return normalized.contains('anne') || normalized.contains('mother')
        ? 'MotherLearnCard'
        : 'UpperLearnCard';
  }

  int _calculateCurrentWeek(Map<String, dynamic> userData) {
    final rawDate = userData['createdAt'];
    DateTime? startDate;
    if (rawDate is Timestamp) startDate = rawDate.toDate();
    if (rawDate is String) startDate = DateTime.tryParse(rawDate);
    if (startDate == null) return 1;
    return max(1, DateTime.now().difference(startDate).inDays ~/ 7 + 1);
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
