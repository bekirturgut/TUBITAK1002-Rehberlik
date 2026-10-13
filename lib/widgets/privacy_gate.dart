import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Pages/privacy_page.dart';
import '../services/privacy_consent.dart';

/// Consent is collected before the login page can read user records.
class PrivacyGate extends StatefulWidget {
  final Widget child;
  const PrivacyGate({super.key, required this.child});
  @override
  State<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends State<PrivacyGate> {
  bool? _accepted;
  bool _saving = false;
  static const key = 'data_consent_$privacyVersion';
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _accepted = prefs.getBool(key) == true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_accepted == true) return widget.child;
    if (_accepted == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Verileriniz ve gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.privacy_tip_outlined, size: 48),
          const SizedBox(height: 20),
          const Text(
            'Uygulama; kullanıcı kaydınızı, giriş geçmişinizi, eğitim ilerlemenizi ve sohbetlerinizi rehberlik/eğitim ve destek için Firebase üzerinden işler. Yetkili uygulama yöneticileri bu kayıtlara erişebilir. Gemini’ye soru gönderimi için ayrıca izin sorulur.',
          ),
          const SizedBox(height: 16),
          const PrivacyButton(),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        '${key}_accepted_at',
                        DateTime.now().toUtc().toIso8601String(),
                      );
                      await prefs.setBool(key, true);
                      if (mounted) setState(() => _accepted = true);
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  },
            child: const Text(
              'Açıklanan veri kullanımına izin ver ve devam et',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'İzin vermiyorsanız devam etmeyebilirsiniz; bu ekrandan hiçbir giriş veya sohbet kaydı oluşturulmaz.',
          ),
        ],
      ),
    );
  }
}
