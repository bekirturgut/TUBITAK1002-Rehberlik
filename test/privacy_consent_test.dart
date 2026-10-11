import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubitak/Pages/privacy_page.dart';
import 'package:tubitak/services/privacy_consent.dart';
import 'package:tubitak/widgets/privacy_gate.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('AI consent is scoped to the user and can be withdrawn', () async {
    expect(await PrivacyConsent.isGranted('a'), isFalse);
    await PrivacyConsent.setGranted('a', true);
    expect(await PrivacyConsent.isGranted('a'), isTrue);
    expect(await PrivacyConsent.isGranted('b'), isFalse);
    await PrivacyConsent.setGranted('a', false);
    expect(await PrivacyConsent.isGranted('a'), isFalse);
  });
  testWidgets('Declining AI permission does not grant consent', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await ensureAiConsent(context, 'a');
              },
              child: const Text('Soru sor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Soru sor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzin vermiyorum'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(await PrivacyConsent.isGranted('a'), isFalse);
  });
  testWidgets('Explicit AI permission is saved only after acceptance', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await ensureAiConsent(context, 'a');
              },
              child: const Text('Soru sor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Soru sor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini’ye aktarılmasına izin veriyorum'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(await PrivacyConsent.isGranted('a'), isTrue);
  });
  testWidgets('Login content stays unmounted until data consent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyGate(child: Text('Giriş içeriği'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giriş içeriği'), findsNothing);
    await tester.tap(
      find.text('Açıklanan veri kullanımına izin ver ve devam et'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giriş içeriği'), findsOneWidget);
  });
}
