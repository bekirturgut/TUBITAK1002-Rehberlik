import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/privacy_gate.dart';
import 'LoginPage.dart';
import 'package:flutter/material.dart';
import '../services/privacy_consent.dart';
import '../services/user_requests.dart';
import '../services/secure_session.dart';

const privacyPolicyText = '''LactiGen Gizlilik Politikası
Son güncelleme: 13 Ekim 2026

LactiGen — Akıllı Emzirme Asistanı, emzirme ve doğum sonrası döneme yönelik eğitim ve destek sunar.

Sorumlu ve iletişim
Uygulama sorumlusu: Reyhan Metin Ayhan.
Gizlilik, hesap ve veri silme başvuruları: reyhanmetin42@outlook.com.

İşlenen veriler
Yönetici tarafından oluşturulan hesaptaki ad, soyad, telefon numarası, kullanıcı kimliği, rol ve giriş bilgileri; giriş geçmişi; eğitim ilerlemesi ve doğru/yanlış cevaplar; sohbet soruları, yanıtlar ve geri bildirimler işlenir. İçerik bildirimleri ve veri silme talepleri de başvurunun takibi için işlenir. Bildirim hizmeti cihaz bildirim belirteci ve bildirim kayıtlarını işleyebilir. Sorularınıza kendiniz eklediğiniz kişisel veya sağlık bilgileri de mesaj içeriğinin parçasıdır. Gereksiz kimlik, iletişim veya üçüncü kişilerin özel bilgilerini paylaşmayın. Firebase hizmetleri hesap güvenliği ve hizmetin çalışması için IP adresi, IP kaynaklı yaklaşık ülke/konum ve cihaz/istemci bilgilerini işleyebilir. GPS konumunuz alınmaz. Parolanız Firebase Authentication üzerinden doğrulanır; profil kaydında açık metin parola saklanmaz.

Amaç ve hizmetler
Veriler hesap erişimi, eğitim ilerlemesi, destek, bildirimler ve güvenlik/şikâyet takibi için kullanılır. Kayıtlar Google Firebase hizmetleri üzerinden saklanır ve işlenir. Yetkili uygulama yöneticileri bu kayıtlara erişebilir. Firebase bağlantıları aktarım sırasında şifrelenir. Hizmetler verilerin Türkiye dışında işlenmesini veya saklanmasını içerebilir. “Beni hatırla” ve izin tercihleri bu cihazda saklanır.

Google Gemini ve ayrı izin
Yapay zekâ destekli soru-cevap için ayrı izin istenir. İzin verdiğinizde sorunuzun metni Google Gemini hizmetine gönderilir; ilgili eğitim içerikleriyle eşleştirilip cevap hazırlanır. Adınız, telefonunuz ve kullanıcı kimliğiniz AI isteğine ayrıca eklenmez; ancak bunları sorunuza yazarsanız metinle birlikte aktarılır. İzin vermeden eğitim ve SSS kullanılabilir. AI iznini bu ekrandan geri alabilirsiniz. Geri alma sonraki gönderimleri engeller; önceki aktarımları veya başlamış bir işlemi geri almaz.

Saklama ve silme
Yayımlanmış saklama politikası uyarınca hesap, sohbet, eğitim ve bildirim kayıtları 1 yıl saklanır. Hesaplar yönetici tarafından oluşturulur. Hesabınızın ve ilişkili verilerinizin silinmesini bu ekrandan talep edebilir veya iletişim adresine başvurabilirsiniz. Talep değerlendirilip sonuçlandırılır; talep oluşturulması anında silme değildir. Silme sırasında ilişkili kayıtlar da kaldırılır. Tutulması gereken kayıtlar varsa gerekçe ve süre başvuru sahibine açıklanır. İzinleri geri almak hesabı veya geçmiş verileri otomatik silmez.

Sağlık bilgileri
LactiGen tıbbi cihaz değildir; tanı koymaz, tedavi sunmaz ve sağlık profesyonelinin değerlendirmesinin yerine geçmez. Yapay zekâ yanıtları yanlış olabilir. Sağlıkla ilgili kararlar için nitelikli bir sağlık profesyoneline başvurun. Acil durumlarda uygulama yanıtını beklemeyin.

Güncel web politikası
https://sites.google.com/view/rehberlik-gizlilik-politikasi/ana-sayfa
''';

class PrivacyPage extends StatefulWidget {
  final String? userId;
  const PrivacyPage({super.key, this.userId});
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool? _granted;
  bool _requestingDeletion = false;
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
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hesabımın ve verilerimin silinmesini talep et'),
            onPressed: _requestingDeletion
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Hesap ve veri silme talebi'),
                        content: const Text(
                          'Talebiniz uygulama sorumlusuna iletilecek. Kimliğiniz doğrulandıktan sonra hesabınız ve ilişkili verileriniz silinir. Bu düğme anında silme yapmaz. İletişim: reyhanmetin42@outlook.com',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Vazgeç'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Talep oluştur'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) return;
                    setState(() => _requestingDeletion = true);
                    try {
                      await UserRequests.requestDeletion(widget.userId!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Silme talebiniz kaydedildi.'),
                        ),
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Talep kaydedilemedi. reyhanmetin42@outlook.com adresine başvurabilirsiniz.',
                          ),
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _requestingDeletion = false);
                    }
                  },
          ),
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
                  'Bu cihazda uygulamayı kullanmaya devam etmek için tekrar izin gerekir. AI izni de kapatılır. Önceki kayıtlar otomatik silinmez; silme için yöneticiye başvurabilirsiniz.',
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
            await SecureSession.signOut();
            final prefs = await SharedPreferences.getInstance();
            for (final key
                in prefs
                    .getKeys()
                    .where(
                      (k) =>
                          k.startsWith('data_consent_') ||
                          k.startsWith('gemini_consent_') ||
                          [
                            'uid',
                            'role',
                            'rememberMe',
                            'phone',
                            'last_fcm_token',
                            'last_fcm_uid',
                          ].contains(k),
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
