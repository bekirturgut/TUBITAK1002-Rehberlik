import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

class ChatPage extends StatefulWidget {
  final String userId;
  final String selectedRole;

  const ChatPage({
    super.key,
    required this.userId,
    required this.selectedRole,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const Color bgColor = Color(0xFFF6F8FC);
  static const Color userBubbleColor = Color(0xFFD7E9FF);
  static const Color botBubbleColor = Colors.white;
  static const Color adminBubbleColor = Color(0xFFFFF1CC);
  static const Color inputBg = Color(0xFFF9F7F2);

  static const Color pendingUserBubbleColor = Color(0xFFFFE8D9);
  static const Color resolvedUserBubbleColor = Color(0xFFE4F6E8);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _sending = false;

  String? _replyingToMessageId;
  String? _replyingToText;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      FirebaseFirestore.instance.collection('chats').doc(widget.userId);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _messagesStream => _chatRef
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .snapshots();

  bool get _isAdminView => widget.selectedRole == "Admin";

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      await _chatRef.set({
        "userId": widget.userId,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_isAdminView) {
        await _sendAdminMessage(text);
      } else {
        await _sendUserMessage(text);
      }

      await _chatRef.set({
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Mesaj gönderilemedi: $e")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendUserMessage(String text) async {
    final userMsgRef = await _chatRef.collection('messages').add({
      "text": text,
      "senderType": "user",
      "senderRole": widget.selectedRole,
      "senderId": widget.userId,
      "createdAt": FieldValue.serverTimestamp(),
      "needsAdminReply": false,
      "isAnswered": false,
    });

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: "europe-west1",
      ).httpsCallable("askFaqBot");

      final result = await callable.call({
        "question": text,
        "userId": widget.userId,
        "sourceMessageId": userMsgRef.id,
      });

      final resultData = Map<String, dynamic>.from(result.data as Map);
      final botAnswer = (resultData["answer"] ?? "").toString();
      final score = (resultData["score"] ?? 0).toDouble();
      final needsFeedback = resultData["needsFeedback"] == true;
      final escalated = resultData["escalated"] == true;

      await _chatRef.collection("messages").add({
        "text": botAnswer,
        "senderType": "bot",
        "senderId": "chatbot",
        "createdAt": FieldValue.serverTimestamp(),
        "relatedQuestion": text,
        "sourceMessageId": userMsgRef.id,
        "score": score,
        "needsFeedback": needsFeedback,
        "showFeedbackButtons": needsFeedback,
        "feedbackGiven": false,
        "isSufficient": null,
        "escalated": escalated,
      });
    } catch (e) {
      debugPrint("Bot error: $e");
    }
  }

  Future<void> _sendAdminMessage(String text) async {
    await _chatRef.collection('messages').add({
      "text": text,
      "senderType": "admin",
      "senderRole": widget.selectedRole,
      "senderId": widget.userId,
      "createdAt": FieldValue.serverTimestamp(),
      "replyToMessageId": _replyingToMessageId ?? "",
      "replyToText": _replyingToText ?? "",
    });

    if (mounted) {
      setState(() {
        _replyingToMessageId = null;
        _replyingToText = null;
      });
    }
  }

  Future<void> _handleBotFeedback({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isSufficient,
  }) async {
    try {
      await _chatRef.collection("messages").doc(messageId).update({
        "feedbackGiven": true,
        "isSufficient": isSufficient,
        "showFeedbackButtons": false,
        "feedbackAt": FieldValue.serverTimestamp(),
      });

      if (!isSufficient) {
        final callable = FirebaseFunctions.instanceFor(
          region: "europe-west1",
        ).httpsCallable("escalateChatToAdmin");

        await callable.call({
          "userId": widget.userId,
          "question": (data["relatedQuestion"] ?? "").toString(),
          "score": (data["score"] ?? 0).toDouble(),
          "sourceMessageId": (data["sourceMessageId"] ?? "").toString(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sorunuz uzman'e yönlendirildi."),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Geri bildiriminiz kaydedildi."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İşlem sırasında hata oluştu: $e")),
      );
    }
  }

  void _startReplyingTo({
    required String messageId,
    required String messageText,
  }) {
    setState(() {
      _replyingToMessageId = messageId;
      _replyingToText = messageText;
    });
  }

  void _cancelReplying() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToText = null;
    });
  }

  bool _isUser(Map<String, dynamic> data) =>
      (data["senderType"] ?? "").toString() == "user";

  bool _isAdmin(Map<String, dynamic> data) =>
      (data["senderType"] ?? "").toString() == "admin";

  bool _isBot(Map<String, dynamic> data) =>
      (data["senderType"] ?? "").toString() == "bot";

  bool _needsAdminReply(Map<String, dynamic> data) =>
      data["needsAdminReply"] == true;

  bool _isAnswered(Map<String, dynamic> data) => data["isAnswered"] == true;

  Color _bubbleColorFor(
      Map<String, dynamic> data, {
        required bool isAdminView,
      }) {
    final senderType = (data["senderType"] ?? "").toString();

    if (senderType == "user") {
      if (isAdminView) {
        if (_needsAdminReply(data) && !_isAnswered(data)) {
          return pendingUserBubbleColor;
        }
        if (_isAnswered(data)) {
          return resolvedUserBubbleColor;
        }
      }
      return userBubbleColor;
    }

    if (senderType == "admin") return adminBubbleColor;

    return botBubbleColor;
  }

  String _senderLabel(Map<String, dynamic> data) {
    final senderType = (data["senderType"] ?? "").toString();
    if (senderType == "admin") return "Admin";
    if (senderType == "bot") return "Chatbot";
    return "Kullanıcı";
  }

  IconData _senderIcon(Map<String, dynamic> data) {
    final senderType = (data["senderType"] ?? "").toString();
    if (senderType == "admin") return Icons.support_agent;
    if (senderType == "bot") return Icons.smart_toy_outlined;
    return Icons.person;
  }

  Color _senderAccent(Map<String, dynamic> data) {
    final senderType = (data["senderType"] ?? "").toString();
    if (senderType == "admin") return const Color(0xFFE0A800);
    if (senderType == "bot") return AppColors.textBlue;
    return const Color(0xFF4A90E2);
  }

  Widget _buildBotFeedbackArea({
    required String messageId,
    required Map<String, dynamic> data,
    required bool showFeedbackButtons,
    required bool feedbackGiven,
    required dynamic isSufficient,
  }) {
    if (showFeedbackButtons) {
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Bu cevap yeterli oldu mu?",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textBlue,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleBotFeedback(
                      messageId: messageId,
                      data: data,
                      isSufficient: true,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Evet"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleBotFeedback(
                      messageId: messageId,
                      data: data,
                      isSufficient: false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Hayır"),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (feedbackGiven) {
      final positive = isSufficient == true;

      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: positive ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: positive ? Colors.green.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              positive ? Icons.check_circle_outline : Icons.support_agent,
              size: 18,
              color: positive ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                positive
                    ? "Bu cevap yeterli olarak işaretlendi."
                    : "Bu cevap yetersiz bulundu ve uzman'e yönlendirildi.",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: positive
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildReplyPreviewBox() {
    if (!_isAdminView || _replyingToMessageId == null || _replyingToText == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD89A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.reply_rounded,
            color: Color(0xFFB87912),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Şu mesaja cevap veriliyor",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB87912),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyingToText!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textBlue,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReplying,
            icon: const Icon(Icons.close_rounded),
            splashRadius: 18,
            color: Colors.grey.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminReplyReference(Map<String, dynamic> data) {
    final replyToText = (data["replyToText"] ?? "").toString().trim();
    if (replyToText.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Bu sorunun cevabı",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            replyToText,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserStatusBadge(Map<String, dynamic> data) {
    final bool pending = _needsAdminReply(data) && !_isAnswered(data);
    final bool answered = _isAnswered(data);

    if (!pending && !answered) return const SizedBox.shrink();

    final String statusText = pending ? "Cevap bekliyor" : "Cevaplandı";
    final Color statusBgColor =
    pending ? const Color(0xFFFFF0E6) : const Color(0xFFEAF8ED);
    final Color statusBorderColor =
    pending ? const Color(0xFFFFC9A6) : const Color(0xFFA9D8B5);
    final Color statusTextColor =
    pending ? const Color(0xFFB86128) : const Color(0xFF2E7D4F);
    final IconData statusIcon = pending
        ? Icons.hourglass_top_rounded
        : Icons.check_circle_outline_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: statusBgColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: statusBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              statusIcon,
              size: 15,
              color: statusTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: statusTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminReplyButton({
    required String messageId,
    required String message,
    required Map<String, dynamic> data,
  }) {
    if (!_isAdminView) return const SizedBox.shrink();
    if (!_isUser(data)) return const SizedBox.shrink();

    final bool pending = _needsAdminReply(data) && !_isAnswered(data);
    if (!pending) return const SizedBox.shrink();

    final bool isSelected = _replyingToMessageId == messageId;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => _startReplyingTo(
            messageId: messageId,
            messageText: message,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor:
            isSelected ? Colors.white : const Color(0xFFB86128),
            backgroundColor:
            isSelected ? const Color(0xFFB86128) : Colors.transparent,
            side: const BorderSide(color: Color(0xFFB86128)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.reply_rounded, size: 18),
          label: Text(isSelected ? "Seçildi" : "Cevapla"),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(_isAdminView),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return _buildEmptyState(_isAdminView);
                  }

                  return ListView.builder(
                    reverse: true,
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final messageId = doc.id;
                      final message = (data["text"] ?? "").toString();
                      final ts = data["createdAt"];

                      String timeText = "";
                      if (ts is Timestamp) {
                        timeText =
                            DateFormat("dd.MM.yyyy  HH:mm").format(ts.toDate());
                      }

                      final isUser = _isUser(data);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildMessageItem(
                          messageId: messageId,
                          data: data,
                          message: message,
                          timeText: timeText,
                          isUser: isUser,
                          isAdminView: _isAdminView,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildReplyPreviewBox(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAdminView) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.learnStart, AppColors.learnEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isAdminView ? Icons.support_agent : Icons.smart_toy_rounded,
              color: AppColors.textBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdminView ? "Uzman Sohbeti" : "Danışma Botu",
                  style: const TextStyle(
                    color: AppColors.textBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isAdminView
                      ? "Kullanıcı mesajlarını yanıtlayabilirsiniz"
                      : "Sorularınızı buradan iletebilirsiniz",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isAdminView) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.bgBlue.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  isAdminView ? Icons.forum_rounded : Icons.chat_bubble_outline,
                  size: 34,
                  color: AppColors.textBlue,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isAdminView ? "Henüz mesaj yok" : "Sohbet başlatılmadı",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAdminView
                    ? "Kullanıcı ilk mesajı gönderdiğinde konuşma burada görünecek."
                    : "Aşağıdan mesaj yazarak sohbeti başlatabilirsiniz 😊",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.blueGrey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem({
    required String messageId,
    required Map<String, dynamic> data,
    required String message,
    required String timeText,
    required bool isUser,
    required bool isAdminView,
  }) {
    final bubbleColor = _bubbleColorFor(
      data,
      isAdminView: isAdminView,
    );
    final label = _senderLabel(data);
    final accent = _senderAccent(data);
    final icon = _senderIcon(data);

    final isBot = _isBot(data);
    final needsFeedback = data["needsFeedback"] == true;
    final showFeedbackButtons = data["showFeedbackButtons"] == true;
    final feedbackGiven = data["feedbackGiven"] == true;
    final isSufficient = data["isSufficient"];
    final escalated = data["escalated"] == true;
    final isAdminMessage = _isAdmin(data);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: accent),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isAdminView && isUser) _buildUserStatusBadge(data),

          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.74,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              border: Border.all(
                color: isUser
                    ? Colors.blue.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isAdminView && isAdminMessage)
                  _buildAdminReplyReference(data),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          _buildAdminReplyButton(
            messageId: messageId,
            message: message,
            data: data,
          ),

          if (isBot && widget.selectedRole != "Admin" && needsFeedback) ...[
            const SizedBox(height: 8),
            _buildBotFeedbackArea(
              messageId: messageId,
              data: data,
              showFeedbackButtons: showFeedbackButtons,
              feedbackGiven: feedbackGiven,
              isSufficient: isSufficient,
            ),
          ],

          if (isBot &&
              widget.selectedRole != "Admin" &&
              !needsFeedback &&
              escalated) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Bu soru uzman desteğine yönlendirildi.",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              timeText,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
              ),
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isAdminView && _replyingToMessageId != null
                      ? "Seçilen soruya cevabınızı yazın..."
                      : "Mesajınızı yazın...",
                  border: InputBorder.none,
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.textBlue,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                child: _sending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}