import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/privacy_gate.dart';
import 'LoginPage.dart';
import 'package:flutter/material.dart';
import '../services/privacy_consent.dart';

const privacyPolicyText = '''Gizlilik Politikası
Sürüm: 10 Ekim 2026

Bu uygulama rehberlik/eğitim ve araştırma kapsamında sunulur. Aşağıdaki açıklama mevcut veri kullanımını anlatır. Araştırmaya katılım için verilen bilgilendirilmiş onamın yerine geçmez.

İşlenen veriler ve amaçları
Yönetici tarafından oluşturulan kullanıcı kaydındaki ad, soyad, telefon, rol ve giriş bilgileri; giriş geçmişi; eğitim kartları ve etkinliklerdeki ilerleme/doğru-yanlış kayıtları; sohbet soruları, cevapları ve geri bildirimler işlenir. Bu bilgiler kullanıcı erişimini, kişiye ait eğitim akışını ve uzman desteğini sağlamak için kullanılır. Bildirim izni verildiğinde bildirim ulaştırmak için cihaz bildirim belirteci ve bildirim kayıtları işlenebilir.

Verilerin saklanması ve erişim
Kayıtlar Google Firebase hizmetleri üzerinden saklanır ve işlenir. Yetkili uygulama/araştırma yöneticileri eğitim ve destek süreçleri için kayıtlara erişebilir. Mevcut hesap yönetimi ve silme işlemleri yönetici üzerinden yürütülür.

Yapay zekâya aktarım
Chatbot için ayrıca izin verirseniz, gönderdiğiniz sorunun metni Google Gemini API hizmetine aktarılır. Soruyu bilgi tabanı ile eşleştirmek ve seçilen eğitim içeriklerinden cevap düzenlemek için bu metin ve ilgili bilgi tabanı içerikleri kullanılır. Adınız, telefonunuz ve kullanıcı kimliğiniz uygulamanın AI isteğine ayrıca eklenmez; ancak sorunun içine kendiniz yazdığınız kişisel veya sağlık bilgileri soru metniyle birlikte aktarılır. Sorularınıza kimlik, iletişim veya başkasına ait özel bilgileri eklemeyin. Hizmetler yurt dışında veri işlenmesini içerebilir.

Tercihleriniz
Yapay zekâ izni isteğe bağlıdır. İzin vermeden eğitim içeriklerini ve SSS bölümünü kullanabilirsiniz. Bu ekrandan AI iznini geri alabilirsiniz; geri alma sonraki soruların Gemini'ye gönderilmesini engeller. Önceki aktarımları geri almaz ve hesabınızı/verilerinizi otomatik silmez. Başlamış bir işlem geri alma anında durdurulamayabilir. Hesabınızın veya verilerinizin silinmesi ve araştırma katılımınız hakkında araştırma yöneticisine başvurabilirsiniz.

Yayın öncesi tamamlanacak bilgiler
Veri sorumlusu kişi/kurum, gizlilik başvuruları için iletişim adresi, veri saklama süreleri ve varsa araştırma/etik kurul bilgileri henüz sağlanmadı. Bu metin bu alanlar tamamlanana kadar taslaktır.
''';

class PrivacyPage extends StatefulWidget {
  final String? userId;
  const PrivacyPage({super.key, this.userId});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool? _granted;
  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      PrivacyConsent.isGranted(widget.userId!).then((value) {
        if (mounted) setState(() => _granted = value);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gizlilik ve AI izni')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (widget.userId != null) ...[
          Text(_granted == true ? 'Gemini izni: Açık' : 'Gemini izni: Kapalı'),
          if (_granted == true)
            OutlinedButton(
              onPressed: () async {
                await PrivacyConsent.setGranted(widget.userId!, false);
                if (mounted) setState(() => _granted = false);
              },
              child: const Text('Yapay zekâ iznini geri al'),
            ),
          const Divider(),
        ],
        OutlinedButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Veri kullanım iznini geri al'),
                content: const Text(
                  'Bu cihazda uygulamayı kullanmaya devam etmek için tekrar izin gerekir. AI izni de kapatılır. Önceki kayıtlar otomatik silinmez; silme ve araştırmadan ayrılma için yöneticiye başvurabilirsiniz.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Vazgeç'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('İzni geri al'),
                  ),
                ],
              ),
            );
            if (confirmed != true) return;
            final prefs = await SharedPreferences.getInstance();
            for (final key
                in prefs
                    .getKeys()
                    .where(
                      (k) =>
                          k.startsWith('data_consent_') ||
                          k.startsWith('gemini_consent_'),
                    )
                    .toList()) {
              await prefs.remove(key);
            }
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => const PrivacyGate(child: LoginPage()),
              ),
              (_) => false,
            );
          },
          child: const Text('Veri kullanım iznini geri al'),
        ),
        const SelectableText(
          privacyPolicyText,
          style: TextStyle(fontSize: 15, height: 1.6),
        ),
      ],
    ),
  );
}

class PrivacyButton extends StatelessWidget {
  final String? userId;
  const PrivacyButton({super.key, this.userId});
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.privacy_tip_outlined),
    label: const Text('Gizlilik ve AI izni'),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrivacyPage(userId: userId)),
    ),
  );
}

Future<bool> ensureAiConsent(BuildContext context, String userId) async {
  if (await PrivacyConsent.isGranted(userId)) return true;
  if (!context.mounted) return false;
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sorunuzu Gemini ile işleyelim mi?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sorunuzun metni, bilgi tabanıyla eşleştirme ve cevap hazırlama için Google Gemini’ye gönderilecek. Sorunuza yazdığınız kişisel ve sağlık bilgileri de bu aktarıma dahil olabilir. İzin isteğe bağlıdır; eğitim içeriklerini ve SSS’yi izinsiz kullanabilirsiniz. İzni Gizlilik ve AI izni ekranından geri alabilirsiniz.',
            ),
            PrivacyButton(userId: userId),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('İzin vermiyorum'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Gemini’ye aktarılmasına izin veriyorum'),
        ),
      ],
    ),
  );
  if (approved != true) return false;
  await PrivacyConsent.setGranted(userId, true);
  return true;
}
