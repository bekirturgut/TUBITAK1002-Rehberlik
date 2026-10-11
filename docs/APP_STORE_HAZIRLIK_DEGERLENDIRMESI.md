> Gizlilik güncellemesi: Uygulama içi taslak politika, genel veri izni ve ayrı Gemini izni/geri alma akışı eklendi; sunucu izinsiz AI çağrılarını reddediyor. Yayınlanmış politika URL'si, kurum/iletişim/saklama bilgileri ve araştırma onamı hâlâ tamamlanmayı bekliyor. Giriş ve hesap silme kapsam dışı bırakıldı. Ayrıntı: [gizlilik uygulaması](GIZLILIK_VE_ONAM.md).

> Güncelleme: Kullanıcı Apple Developer üyeliği/imzalama ve mağaza metadata/URL hazırlığını şimdilik erteledi. İkon düzeltmesi tamamlandı. Chatbot ve bekleyen soru düzeltmelerinin durumu [ayrı kayıtta](CHATBOT_DUZELTMELERI.md).

# App Store yayın hazırlığı değerlendirmesi

Tarih: 10 Ekim 2026. İncelenen çalışma kopyası: `08f5327` üzerine yerel Flutter/iOS çalıştırma düzeltmeleri.

**Sonuç: Uygulama şu anda App Store yayınına hazır değil.** Simülatörde açılıyor; fakat dağıtım imzası, veri güvenliği, gizlilik/onam ve mağaza hazırlığında eksikler var. Bu incelemede uygulama veya backend kaynakları değiştirilmedi; yalnızca bu rapor eklendi ve imzasız Release derlemesi çalıştırıldı.

## Kapsam ve doğrulama

Esas ürün, bu oturumda çalıştırılan Flutter uygulamasıdır (`lib/`, `ios/`). Depoda ayrıca bağımsız Swift/SwiftUI istemcisi (`native-ios/`) var. Swift istemcisinin CI sonuçları ve imzalama workflow'u Flutter uygulamasına ait değildir. İki istemci aynı `com.tubitak.tubitak` kimliğini kullanıyor; yayınlanacak istemci seçilmelidir.

- Flutter 3.38.5 / Dart 3.10.4; Xcode 27.0 / iOS SDK 27.0.
- Flutter minimum iOS hedefi 15.0; Swift istemcisinin hedefi 16.0.
- Flutter iPhone 17 / iOS 27 simülatöründe derlendi, açıldı ve giriş ekranı görsel olarak doğrulandı.
- Mevcut Flutter giriş ekranı testi geçti. Önceki analizde 62 bilgi seviyesinde stil/async-context bildirimi vardı; Dart derleme hatası yoktu.
- İmzasız gerçek cihaz Release derlemesi: **BAŞARILI** — `flutter build ios --release --no-codesign --no-pub`; 292,7 saniyede 54,4 MB `Runner.app` üretildi. Bu imzasız uygulama, App Store'a gönderilebilir imzalı IPA/Archive değildir.
- `security find-identity -v -p codesigning`: **0 valid identities found**.
- Simülatör ve gerçek cihaz Release paketlerinin her birinde 22 adet okunabilir SDK privacy manifest bulundu.
- Flutter ve Swift istemcilerinin 1024×1024 mağaza ikonları düzeltildi; `sips` her ikisinde de `hasAlpha: no` doğruladı. Diğer iOS ikonlarının alfa kanalları da kaldırıldı.

Apple Developer/App Store Connect hesabına, canlı Firebase kurallarına, APNs ayarlarına, Gemini faturalandırmasına ve araştırmanın hukuki belgelerine erişilmedi. Dolayısıyla üyelik, canlı güvenlik, sözleşme ve gerçek cihaz teslimi hakkında doğrulanmış olumlu sonuç yoktur. Mağaza yükleme doğrulaması ve App Review yapılmadı.

## 1. Dağıtım imzası ve geliştirici hesabı — yayın engeli

Flutter `ios/Runner.xcodeproj/project.pbxproj` içinde `DEVELOPMENT_TEAM` yok. Kaynakta dağıtım provisioning profili veya imza kimliği hazır değil; bu bilgisayarda geçerli sertifika/özel anahtar çifti de bulunamadı. Simülatör imzası App Store dağıtım imzası yerine geçmez.

Gereken sonuç: aktif geliştirici hesabı, yetkili ekip, bu ekibe kayıtlı açık App ID, App Store Connect uygulama kaydı ve geçerli dağıtım imzasıyla Archive/IPA. Xcode otomatik imzalama kullanılabilir; elle `.p12`/profil yönetimi tek zorunlu yöntem değildir. `com.tubitak.tubitak` kimliğinin ilgili ekipte kullanılabildiği hesap üzerinden doğrulanmalıdır.

Standart Apple Developer üyeliği yıllık 99 USD'dir; yerel ücret farklı olabilir. Uygun eğitim/kamu kuruluşları ücret muafiyeti isteyebilir; TÜBİTAK projesi olmak tek başına muafiyet sağlamaz. Yayıncı şahıs mı üniversite/kurum mu olacak, hak sahipliğiyle birlikte belirlenmelidir. [Apple üyelik bilgisi](https://developer.apple.com/programs/enroll/), [ücret muafiyeti](https://developer.apple.com/help/account/membership/fee-waivers/).

Depodaki `.github/workflows/native-ios-signed.yml` yalnızca Swift istemcisi için hazırlanmış. Gerçek imzalı çıktısı bu incelemede doğrulanmadı; Flutter için hazır yayın pipeline'ı olarak kabul edilmemelidir.

## 2. SDK, sürüm ve ikon — kısmen hazır

Mevcut Xcode/iOS SDK ve minimum iOS hedefi güncel mağaza eşiklerini karşılıyor. Apple'ın 28 Nisan 2026'dan itibaren bildirdiği eşik Xcode/iOS SDK 26 veya sonrası; 9 Eylül 2026'dan itibaren minimum hedef iOS 13 veya sonrası. [Güncel gereksinimler](https://developer.apple.com/news/upcoming-requirements/).

Flutter sürümü `1.0.0+1`, Swift sürümü `2.0.0` olarak tanımlı. Bu farklılık tek başına hata değildir; ancak yayınlanacak ürünün pazarlama sürümü ve build numarası App Store Connect'teki kayıtla eşleştirilmelidir. Aynı build numarası daha önce yüklenmişse yeni yükleme için artırılmalıdır; mevcut kayıt görülmedi.

Flutter ve Swift düz PNG mağaza ikonları opaque RGB biçimine dönüştürüldü; boyutları 1024×1024, alfa kanalları yok. App Store yükleme doğrulaması üyelik alınana kadar bekliyor; simülatörde ikonun görünmesi mağaza kabulünü kanıtlamaz. Bu tespit yeni Icon Composer katmanlı ikon kurallarına ilişkin genel bir yasak değildir; mevcut proje klasik PNG asset catalog kullanıyor. [Apple geliştirici forumundaki ilgili yükleme hatası](https://developer.apple.com/forums/thread/96003).

## 3. Giriş ve veri erişimi — kritik güvenlik sorunu

`lib/Pages/LoginPage.dart:154` telefonla `users` sorguluyor; `:169` Firestore belgesindeki `password` değerini cihazda girilen şifreyle karşılaştırıyor. `lib/Pages/UserDetailPage.dart:68` şifreyi olduğu gibi belgeye yazıyor. Şifre için güvenli sunucu doğrulaması/hashing akışı görünmüyor. Kullanıcı belgesi okunabildiğinde şifre alanı da istemciye geliyor.

`LoginPage.dart:117` hatırlanan `uid`/`role` değerlerini SharedPreferences'dan alıp tekrar kimlik doğrulamadan rol sayfasına geçiyor. Giriş akışında Firebase Auth oturumu kurulmadığı görülüyor; yalnızca Admin çıkışında `signOut` var. Yerel rol seçimi veya kayıt gerçek sunucu yetkilendirmesinin yerine geçmez.

Canlı Firestore kuralları depoda yok; yalnızca izole emulator test kuralları var. Canlı verinin herkese açık olduğunu bu inceleme kanıtlamaz. Buna karşılık mevcut kimliksiz istemci akışının kullanıcı/rol bazında nasıl güvenli yetkilendirildiği gösterilemiyor. Yayın öncesi sunucuda doğrulanan kimlik ve rol, şifreleri istemciye vermeyen giriş, kullanıcı izolasyonu, yönetici yetki kontrolleri ve kuralların negatif erişim testleri gerekir. Mevcut kullanıcı verilerini koruyacak bir geçiş planı yapılmalıdır. [Firestore erişim kontrolü](https://firebase.google.com/docs/firestore/security/rules-conditions).

## 4. Sunucu fonksiyonları — kritik doğrulama eksikliği

`functions/index.js:657` (`askFaqBot`) ve `:976` (`escalateChatToAdmin`) istemcinin gönderdiği `userId`/`sourceMessageId` değerlerini kabul ediyor. Kaynakta `request.auth` kontrolü, bu kimliğin çağıran kullanıcıya ait olduğunun doğrulanması veya `enforceAppCheck` yok. İşlemler Admin SDK ile yürütülüyor; yalnızca istemci Firestore kurallarını düzeltmek bu fonksiyonlardaki yetki eksikliğini gidermez.

Dağıtılmış uçların IAM ayarları görülmedi. Erişilebilir olmaları durumunda başka kullanıcı adına işlem ve AI maliyeti oluşturma riski vardır. Kimlik/nesne sahipliği, yönetici rolü, girdi boyutu sınırı ve kullanıcı bazlı kötüye kullanım sınırlaması doğrulanmalıdır. App Check yardımcı katmandır; kullanıcı kimliği ve yetki denetiminin yerine geçmez. `maxInstances: 10` tek başına kullanıcı kotası değildir.

Backend bağımlılıklarının güncel npm audit sonucu: **24 etkilenen paket kaydı: 3 kritik, 9 yüksek, 10 orta, 2 düşük** (`npm audit --package-lock-only --omit=dev`). Örnek kritik paketler: `protobufjs`, `proxy-addr`, `websocket-driver`. Bunlar 24 bağımsız açık olarak yorumlanmamalı; geçişli bağımlılık zincirleri aynı bildirimi taşıyabilir. Kilit dosyasındaki üretim bağımlılıkları incelendi; canlı dağıtım sürümü ve her açığın bu uygulamada sömürülebilirliği doğrulanmadı. Güncelleme sonrası backend regresyon testi gerekir; bazı öneriler firebase-admin major sürüm değişikliği içeriyor. Otomatik/force güncelleme yapılmadı. [Tarama kanıtı](APP_STORE_NPM_AUDIT_2026-10-10.json). Audit sonucu canlı sistemin tamamı için güvenlik sertifikası değildir.

## 5. Gizlilik, kişisel veri ve araştırma — hazır değil

Uygulamada kolay erişilen gizlilik politikası bağlantısı veya ayrıntılı onam akışı bulunamadı. Girişteki bilimsel kullanım açıklaması tek başına politika/onam değildir. Apple, uygulama içi ve mağaza metadata'sında gizlilik bağlantısı; kişisel verinin üçüncü taraf AI'ya paylaşımında önceden açık izin ister. İnsan katılımcılı sağlık araştırmasıysa katılımcı onamı ve bağımsız etik onay gerekir. [Apple kuralları, 5.1.1–5.1.3](https://developer.apple.com/app-store/review/guidelines/).

Kaynakta görülen veri envanteri: ad/soyad, telefon, kullanıcı kimliği ve rolü, giriş geçmişi, sohbet/sorular/yanıtlar, quiz/öğrenme sonuçları, FCM cihaz tokenı ve bildirim kayıtları. Serbest sorularda sağlık veya aileye ait hassas bilgiler bulunabilir. Gerçek içeriğe göre App Privacy formu doldurulmalı; yalnızca kullanılan SDK listesinden veya örnek bir formdan kopyalanmamalıdır. [Apple App Privacy açıklaması](https://developer.apple.com/app-store/app-privacy-details/).

Veri sorumlusu, amaç/hukuki dayanak, saklama süresi, erişen araştırmacılar, silme/çekilme süreci ve Firebase/Gemini aktarımı tanımlanmalı. Fonksiyonun `europe-west1` bölgesinde olması tüm Firebase/Gemini verilerinin yalnızca aynı bölgede işlendiğini kanıtlamaz. Sağlık verileri ve yurt dışı aktarımının hukuki zemini kurumun KVKK sorumlusu tarafından değerlendirilmelidir; KVKK'nın 6 ve 9. maddeleri 2024'te değişmiştir. [KVKK resmi duyurusu](https://www.kvkk.gov.tr/Icerik/7834/6698-Sayili-Kisisel-Verilerin-Korunmasi-Kanununda-Yapilan-Degisiklikler-Hakkinda-Kamuoyu-Duyurusu).

Etik kurul/TÜBİTAK/üniversite izin belgelerinin bulunmaması, alınmadıkları anlamına gelmez; bu incelemede görülmediler. Araştırmanın sağlık araştırması kapsamına girip girmediği ve gerçek içerik ayrıca teyit edilmelidir.

## 6. Gemini koşulları ve sağlık içeriği — yüksek öncelik

`functions/index.js:670` kullanıcının sorusunu embedding için Google'a gönderiyor; `:624` başlayan cevap oluşturma da soru ve eşleşen FAQ içeriğini Gemini'ye gönderiyor. Ayrı bir AI paylaşım onayı görünmüyor. API anahtarının backend ortam değişkeninde olması olumlu; uygulamadaki Firebase yapılandırma anahtarıyla aynı tür sır değildir.

Google'ın incelenen Gemini API koşulları: ücretsiz hizmete hassas/kişisel bilgi gönderilmemeli; ücretsiz kullanımın girdileri ürün geliştirmede ve insan incelemesinde kullanılabilir. Aktif faturalandırmalı projedeki ücretli hizmet farklı veri işleme şartlarına tabidir. Koşullar ayrıca 18 yaş altına yönelik/erişilmesi muhtemel istemcileri ve tıbbi tavsiye/klinik kullanımı sınırlar. Canlı hesabın ücretli/ücretsiz durumu görülmedi. [Gemini API koşulları](https://ai.google.dev/gemini-api/terms).

Prompt yalnızca FAQ içeriğini kullanmasını ve teşhis uydurmamasını söylüyor; bu olumlu ama tek başına tıbbi güvenlik veya sözleşme uygunluğu sağlamaz. İçerik eğitim/destek kapsamında sınırlandırılmalı, AI yanıtı kullanıcıya açıkça belirtilmeli, gerçek uzman yetkinliği ve acil durum yönlendirmesi tanımlanmalı. Kaynakta FAQ/kaynaklardan bahsetmemesi isteniyor; doğruluk ve içerik kaynağı sunumu ayrıca ele alınmalı. Apple yaş derecesi formu ile Google'ın hizmet yaş koşulu ayrı konulardır.

## 7. Hesap silme ve oturum kapatma — eksik

Silme işlemi yalnızca yönetici ekranında görünüyor. `lib/Pages/UsersTab.dart:27` bildirimler, loginHistory, scheduledNotifs ve kullanıcı belgesini siliyor; sohbetler, doğru/yanlış kartlar, kuyruk/uyarı kayıtları ve diğer ilişkili veriler kapsamda değil. Firestore'da üst belgeyi silmek bütün alt koleksiyonları otomatik silmez.

Kayıt yönetici tarafından oluşturuluyor; kullanıcıya açık kayıt ekranı görünmüyor. Apple'ın hesap silme şartının bu dağıtım/kayıt modeline uygulanması inceleme notlarında açıklanmalıdır; yalnızca yönetici silmesini yeterli saymamak gerekir. Hesap oluşturmayı destekleyen uygulamalarda kullanıcı uygulama içinden silmeyi başlatabilmelidir. Araştırmadan çekilme/veri silme süreci ayrıca gereklidir. [Apple hesap silme açıklaması](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).

Anne/Üst Kuşak çıkışı yalnızca yerel tercihleri temizliyor. FCM tokenı kullanıcıdan ayrılmıyor; token-refresh listener'ları iptal edilmiyor; planlı yerel bildirimler iptal edilmiyor. Aynı cihazda başka kullanıcıyla girişte eski hesaba ait bildirim/kimlik ilişkisinin sürmesi test edilmeli. `FcmTokenService` ve `NotificationBootstrap` ayrı listener kuruyor.

## 8. Push bildirimleri — gerçek cihazda hazır olduğu gösterilemedi

Flutter Runner'da `CODE_SIGN_ENTITLEMENTS`, `aps-environment` ve `UIBackgroundModes: remote-notification` tanımları görünmüyor. Push capability ve profile entitlement eşleşmesi gerekir. Remote-notification arka plan modu, kullanılacak arka plan/silent push davranışı için ayrıca yapılandırılmalıdır; her foreground alert için tek başına zorunlu değildir.

Firebase'de APNs anahtarı/sertifikası doğrulanmadı. `onMessageOpenedApp`/`getInitialMessage` ile push'tan ilgili sayfaya geçiş bulunamadı. Yerel bildirim callback'i opsiyonel ve başlangıçta verilmemiş. Foreground/background/terminated teslim, token yenilenmesi, izin reddi ve çıkış sonrası davranış gerçek iPhone/TestFlight üzerinden test edilmeli. Swift istemcisinde production push entitlement bulunması Flutter istemcisine otomatik aktarılmaz. [Firebase Apple FCM kurulumu](https://firebase.google.com/docs/cloud-messaging/ios/get-started).

## 9. SDK privacy manifest ve şifreleme — kısmen hazır

Simülatör paketindeki 22 SDK manifesti XML olarak okunuyor; Flutter, Firestore, Messaging, shared_preferences ve yerel bildirim manifestleri bunlar arasında. Bu olumlu fakat imzalı Release archive'ın tüm binary SDK imzalarıyla kabul edileceğini kanıtlamaz. Xcode privacy raporu ve App Store validation ayrıca yapılmalı. [Apple SDK kuralları](https://developer.apple.com/support/third-party-SDK-requirements/).

Flutter Runner'da uygulamaya ait manifest bulunmaması tek başına kesin red gerekçesi değildir; uygulamanın doğrudan kullandığı required-reason API'lar ve SDK manifestlerinin kapsamı birlikte değerlendirilir. Swift istemcisi doğrudan `UserDefaults` kullanıyor ve uygulama manifesti görünmüyor; bu istemci yayınlanacaksa ayrıca ele alınmalı. Manifest, App Privacy formu ve gizlilik politikası birbirinin yerine geçmez.

`ITSAppUsesNonExemptEncryption` beyanı görünmüyor; bu anahtarın yokluğu tek başına yayın yasağı değildir. TLS/Firebase/BoringSSL kullanımı nedeniyle export compliance soruları doğru yanıtlanmalı, uygun muafiyet varsa beyan edilmeli. Projenin yalnızca standart/muaf şifreleme kullandığı doğrulanmadan rastgele `false` eklenmemeli. [Apple export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/).

## 10. Açık kaynak, görseller ve marka — doğrulama gerekli

Çözümlenmiş 88 Dart paket kaydı incelendi; runtime, dev ve farklı platform bağımlılıkları birlikte sayılmıştır. İlk sınıflandırma 71 BSD ailesi, 7 MIT, 6 Apache-2.0; ayrıca Linux `dbus` MPL-2.0, SDK alt paketleri ve uygulamanın kendisi vardı. MPL paketinin listede olması iOS binary'ye dahil olduğu anlamına gelmez. İncelenen listede zorunlu GPL dağıtım engeli saptanmadı; bu tam hukuki lisans sertifikası değildir.

iOS Pods lisanslarında Apache/BSD, nanopb zlib benzeri koşulları ve BoringSSL'nin OpenSSL/SSLeay/ISC/MIT bileşenleri var. Pods acknowledgements plist'i 39 kayıt içeriyor; bu dosyanın üretilmesi kullanıcıya lisansların sunulduğunu kanıtlamaz. Uygulamada Lisanslar/Acknowledgements ekranı bulunamadı. Flutter'ın lisans kayıtları yanında native SDK bildirimleri de son dağıtımda korunmalı/sunulmalı.

Backend ana paketleri: @google/genai ve firebase-admin Apache-2.0; firebase-functions MIT; dotenv BSD-2-Clause. Lockfile'da ayrıca CC-BY-4.0 `caniuse-lite` ve BSD veya GPL seçeneği sunan `node-forge` bulunuyor. Bunlar otomatik App Store engeli değildir; kullanılan lisans seçeneği/atıf yükümlülükleri korunmalıdır. Backend paketleri iOS uygulamasına doğrudan paketleniyor varsayılmamalıdır.

Projenin kendi LICENSE dosyasının bulunmaması App Store'a kapalı kaynak uygulama göndermeyi engellemez. Kaynağı MIT lisanslamak veya herkese açmak zorunlu değildir. Özel EULA verilmezse Apple standart EULA'sı uygulanır; araştırma katılım metninin yerine geçmez. [Apple EULA açıklaması](https://developer.apple.com/help/app-store-connect/manage-app-information/provide-a-custom-license-agreement).

`assets/` görsellerinin, ikonun ve sunucudaki eğitim/FAQ içeriğinin hakları görülmedi. Görsel kaynak/izin kayıtları hazırlanmalı. Görünen “Tubitak” adı kurum bağlantısı izlenimi yaratıyor; destek alınmasıyla marka kullanım yetkisi aynı şey değildir. TÜBİTAK/üniversite marka izni ve yazılımın hak sahibi doğrulanmalı. [Apple fikri mülkiyet kuralları, 5.2](https://developer.apple.com/app-store/review/guidelines/).

## 11. Mağaza metadata'sı ve ürün testi — tamamlanmalı

App Store Connect kaydı, destek/gizlilik URL'leri, açıklama, telif sahibi, yaş derecesi, iPhone/iPad ekran görüntüleri, dağıtım ülkeleri ve reviewer test hesabı doğrulanmadı. İnceleme için canlı backend ve erişilebilir test hesabı sağlanmalı; araştırmaya özel rol/kayıt modeli ve uzman/AI ayrımı açıklanmalı. [Apple inceleme öncesi koşulları](https://developer.apple.com/app-store/review/guidelines/).

Kodda uygulama içi ücretli dijital satış/abonelik veya üçüncü taraf sosyal giriş görünmedi. Bu gözlemle ayrıca ödeme sistemi ya da Sign in with Apple ekleme zorunluluğu çıkmıyor. App Tracking Transparency de sırf Firebase kullanılıyor diye otomatik gerekli sayılmamalı; gerçek tracking davranışı esas alınır. [Apple kuralları](https://developer.apple.com/app-store/review/guidelines/).

Apple SDK koşullarının karşılanması gerçek cihaz uyumluluğunu kanıtlamaz. Kullanıcı/admin izolasyonu, gerçek giriş, quiz, uzman sohbeti, AI hata/timeout davranışı, çevrimdışı akış, bildirim reddi, yeniden giriş/çıkış ve silme testleri eksik. Flutter hedefi iPhone ve iPad; küçük ekran, iPad, yön değişimi, büyük yazı/VoiceOver ve klavye taşması kontrol edilmeli. Bir giriş ekranı testi bütün bu akışların geçtiğini göstermez. Repo belgelerindeki 39 Swift/emulator kontrolü mevcut Flutter Release test kapsamına aktarılmamalıdır.

Sohbet şu an kullanıcı-bot/yönetici modeli; kullanıcılar arası genel paylaşım görünmüyor. Genel kullanıcı içeriği/paylaşım eklenirse filtreleme, şikâyet, engelleme ve iletişim mekanizmaları Apple 1.2 kapsamında ayrıca değerlendirilir. [Apple kullanıcı içeriği kuralları](https://developer.apple.com/app-store/review/guidelines/).

Araştırma katılımcılarına sınırlı dağıtım için Unlisted App seçeneği düşünülebilir; yine review ve aynı güvenlik/gizlilik şartları geçerlidir. Linki bilen herkes erişebildiğinden link gizliliği kimlik doğrulamanın yerine geçmez. [Apple Unlisted dağıtımı](https://developer.apple.com/support/unlisted-app-distribution/).

## Yayın öncesi önerilen sıra

1. Yayınlanacak istemciyi, kurumsal hak sahibini ve dağıtım modelini belirle.
2. Kimlik doğrulama/şifre/rol kontrolü, Firestore kuralları ve callable sahiplik kontrollerini düzelt; kullanıcı veri geçişini planla.
3. Gizlilik/KVKK, araştırma onamı/etik belgeleri, Gemini paylaşım izni ve veri silme süreçlerini tamamla.
4. İkonu ve lisans/marka haklarını tamamla; push capability/APNs ve oturum çıkışını doğrula.
5. Developer Team/App ID/App Store Connect kaydını kur; gerçek imzalı Archive üret ve validation çalıştır.
6. Gerçek iPhone/iPad TestFlight testlerini tamamla; privacy/yaş/export formlarını ve review materyallerini doldur.

Dağıtım sertifikası tek başına yukarıdaki kaynak ve süreç eksiklerini çözmez. Değerlendirmenin tamamlanması, Apple'ın kabul kararı yerine geçmez.
