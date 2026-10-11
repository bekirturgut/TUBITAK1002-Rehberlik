import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Derives pending questions from existing messages, ignoring stale chat flags.
Set<String> pendingQuestionIds(Map<String, Map<String, dynamic>> messages) {
  final repliedTo = messages.values
      .where((m) => m['senderType'] == 'admin')
      .map((m) => m['replyToMessageId'])
      .whereType<String>()
      .toSet();
  return messages.entries
      .where(
        (entry) =>
            entry.value['senderType'] == 'user' &&
            (entry.value['text'] ?? '').toString().trim().isNotEmpty &&
            entry.value['needsAdminReply'] == true &&
            entry.value['isAnswered'] != true &&
            !repliedTo.contains(entry.key),
      )
      .map((entry) => entry.key)
      .toSet();
}

/// Each chat's live messages are authoritative; deleted chats release listeners.
Stream<Set<String>> watchPendingChats(FirebaseFirestore firestore) {
  late StreamController<Set<String>> controller;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? chatsSubscription;
  final subscriptions =
      <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
  final pending = <String>{};
  final loaded = <String>{};
  void emit() {
    if (loaded.length == subscriptions.length && !controller.isClosed) {
      controller.add(Set<String>.of(pending));
    }
  }

  controller = StreamController<Set<String>>(
    onListen: () {
      chatsSubscription = firestore.collection('chats').snapshots().listen((
        snapshot,
      ) {
        final ids = snapshot.docs.map((d) => d.id).toSet();
        for (final id in subscriptions.keys.toList()) {
          if (!ids.contains(id)) {
            subscriptions.remove(id)?.cancel();
            pending.remove(id);
            loaded.remove(id);
          }
        }
        for (final id in ids) {
          if (subscriptions.containsKey(id)) continue;
          subscriptions[id] = firestore
              .collection('chats')
              .doc(id)
              .collection('messages')
              .snapshots()
              .listen((messages) {
                loaded.add(id);
                final hasPending = pendingQuestionIds({
                  for (final doc in messages.docs) doc.id: doc.data(),
                }).isNotEmpty;
                if (hasPending) {
                  pending.add(id);
                } else {
                  pending.remove(id);
                }
                emit();
              }, onError: controller.addError);
        }
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await chatsSubscription?.cancel();
      await Future.wait(subscriptions.values.map((s) => s.cancel()));
    },
  );
  return controller.stream;
}
