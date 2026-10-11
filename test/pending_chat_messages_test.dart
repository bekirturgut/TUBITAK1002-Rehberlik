import 'package:flutter_test/flutter_test.dart';
import 'package:tubitak/services/pending_chat_messages.dart';

void main() {
  test(
    'Counts real unanswered user questions, excluding empty phantom records',
    () {
      expect(
        pendingQuestionIds({
          'pending': {
            'senderType': 'user',
            'text': 'Soru',
            'needsAdminReply': true,
            'isAnswered': false,
          },
          'answered': {
            'senderType': 'user',
            'text': 'Eski soru',
            'needsAdminReply': true,
            'isAnswered': true,
          },
          'phantom': {'needsAdminReply': true, 'isAnswered': false},
          'empty': {'senderType': 'user', 'text': ' ', 'needsAdminReply': true},
          'bot': {
            'senderType': 'bot',
            'text': 'Yanıt',
            'needsAdminReply': true,
          },
        }),
        {'pending'},
      );
    },
  );
  test('An actual referenced admin reply overrides stale pending flags', () {
    expect(
      pendingQuestionIds({
        'old': {
          'senderType': 'user',
          'text': 'Eski soru',
          'needsAdminReply': true,
        },
        'new': {
          'senderType': 'user',
          'text': 'Yeni soru',
          'needsAdminReply': true,
        },
        'reply': {
          'senderType': 'admin',
          'text': 'Yanıt',
          'replyToMessageId': 'old',
        },
      }),
      {'new'},
    );
  });
  test('Deleting the last question leaves no pending question', () {
    expect(
      pendingQuestionIds({
        'reply': {'senderType': 'admin', 'replyToMessageId': 'deleted'},
      }),
      isEmpty,
    );
  });
}
