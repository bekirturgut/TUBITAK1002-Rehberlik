# Gizlilik ve onam uygulaması

Kapsam: Kullanıcının talebiyle yalnızca gizlilik/veri aktarım izni düzenlendi. Şifre saklama/giriş doğrulaması ve yöneticinin hesap silme yöntemi değiştirilmedi.

## Uygulama

- Giriş ekranı oluşturulmadan önce genel veri kullanımı açıklaması ve açık izin ekranı gösterilir.
- Giriş, Anne, Üst Kuşak ve Uzman ekranlarından gizlilik metnine erişilir.
- Chatbot sorusu kaydedilip gönderilmeden önce Google Gemini'ye soru metni aktarımı için ayrı izin alınır. Ret, kabul sayılmaz; eğitim ve SSS kullanılabilir.
- AI izni kullanıcı kimliği ve politika sürümüne bağlıdır. Kabul zamanı bu cihazdaki tercihlerde UTC olarak kaydedilir. Genel veri izni cihaz/politika sürümüne bağlıdır. Bunlar merkezi araştırma onam kaydı değildir.
- Gizlilik ekranında AI izni geri alınabilir. Genel veri izni geri alındığında bu cihazdaki izin kayıtları temizlenir ve uygulama izin ekranına döner; eski Firebase verileri silinmez, hesap yönetimi değişmez. Daha önce başlatılmış AI işlemi veya önceki aktarım geri alınmaz.
- `askFaqBot`, güncel `privacyVersion` ve açık `aiConsent: true` olmadan AI işlemine izin vermez. İzin beyanı mevcut istemciden gelir; yeni bir kimlik doğrulama sistemi eklenmedi. Eski uygulama sürümleri bu alanları göndermediği için chatbot çağrıları reddedilir; güncel istemci gerekir.

## Yayın için gerekli bilgiler

Veri sorumlusu kişi/kurum adı, iletişim e-postası, veri saklama süresi ve araştırma/etik kurul/onam bilgileri kullanıcıdan bekleniyor. Politika bunlar sağlanana kadar açıkça taslak olarak gösteriliyor. Genel uygulama izni etik kurulca onaylanmış araştırma katılım onamının yerini almaz.

`privacy-site/index.html` uygulama metninin web kopyasıdır; henüz internete yayınlanmadı. Bilgiler tamamlandıktan sonra mevcut Hosting içeriği kontrol edilerek ayrı `firebase.privacy.json` yapılandırmasıyla HTTPS sayfası yayımlanabilir. Varsayılan `firebase.json` veya Firestore erişim kuralları değiştirilmedi. Son URL App Store Connect'in Privacy Policy URL alanına eklenmelidir.

## Doğrulama

Flutter: kullanıcıya özel izin, izin reddi/kabulü, izin verilmeden giriş içeriğinin oluşturulmaması ve mevcut testler dahil 8 test başarılı. Backend: güncel izin olmayan çağrıların reddi dahil 16 demo entegrasyon testi başarılı. Statik analizde yeni derleme hatası yok. Canlı sunucu yayını ve simülatör kontrolünün sonucu aşağıya eklenir.

Canlı sonuç: `askFaqBot` izin kontrolü yayını tamamlandı. İzinsiz deneme HTTP 400 / FAILED_PRECONDITION, güncel izinli deneme HTTP 200 / dolu cevap döndürdü. Testte kullanıcı ID'si veya kaynak mesaj gönderilmedi, canlı sohbet/uyarı oluşturulmadı. iPhone 17 simülatöründe uygulamanın gizlilik ekranıyla açıldığı görsel olarak doğrulandı.
