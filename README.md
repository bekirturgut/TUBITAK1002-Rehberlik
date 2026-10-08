# Rehberlik — Native iOS / SwiftUI

TÜBİTAK projesinin anne, üst kuşak ve uzman deneyimleri için native iOS istemcisi **[native-ios/](native-ios/)** altında bulunur. SwiftUI, Firebase Apple SDK ve test edilebilir bir Swift çekirdeği kullanır; iOS uygulaması Flutter veya Dart çalışma zamanı içermez.

Eski Flutter kaynakları Android sürümü ve geçiş referansı için korunmuştur. Eski kullanım belgesi: [Flutter referansı](docs/FLUTTER_REFERENCE.md).

## Kapsam

- Telefon/şifre ve rol ile sunucuda doğrulanan giriş; Firebase Auth oturumu.
- Anne ve üst kuşak ana ekranları, SSS, haftalık öğrenme kartları.
- Dört seçenekli quiz, yanlışları tekrar çözme, ilerleme ve kalıcı kazanılmış rozetler.
- Gemini bilgi tabanı, uzman desteğine yönlendirme, soruya bağlı uzman cevapları ve geri bildirim.
- FCM/APNs, bildirim şablonları ve yaklaşan bildirim listesi.
- Uzman panelinde kullanıcı, kart, SSS, chatbot ve bildirim yönetimi; giriş geçmişi.

## Geliştirme ve doğrulama

Swift kaynakları Windows'ta düzenlenebilir. iOS derlemesi ve simülatör testleri macOS/Xcode üzerinde yapılır. [GitHub Actions iş akışı](.github/workflows/native-ios.yml), macOS üzerinde Swift çekirdek testlerini, uygulama/model/UI testlerini ve imzasız cihaz derlemesini çalıştırır. Backend testleri gerçek Firebase emülatörlerinde yürütülür.

```sh
cd functions
npm ci
npm test
cd ..
firebase emulators:exec --only firestore,auth --project demo-rehberlik 'npm --prefix functions run test:integration'
```

Firebase CLI emülatörleri Java 21 gerektirir. Testler `demo-rehberlik` projesini kullanır ve Firestore emülatörü olmadan entegrasyon testleri çalışmayı reddeder.

macOS üzerinde:

```sh
swift test --package-path native-ios/Core
brew install xcodegen
cd native-ios
xcodegen generate
xcodebuild test -project Rehberlik.xcodeproj -scheme Rehberlik -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

## Canlıya geçiş

**Bu değişiklikler canlı Firebase'e otomatik dağıtılmaz.** Yeni backend ve güvenlik kuralları eski Flutter giriş yapısıyla uyumlu değildir. Kullanıcı kimliklerini koruyan kontrollü bir geçiş gerekir.

1. Git geçmişinde bulunmuş Gemini anahtarını iptal edip yenileyin. `.env` yeni sürümde takip edilmez; geçmişteki değerin geçerliliği yalnızca sağlayıcı tarafında iptal edilir.
2. Firestore yedeği alın ve eski istemcideki yazma işlemlerini durdurun.
3. Kullanıcı ve bildirim geçiş araçlarını önce dry-run modunda çalıştırın.
4. Doğrulanmış geçiş planını staging ortamında uygulayın; kullanıcıları, şifreleri ve ilişkili kayıtları kontrol edin.
5. Secret Manager, Auth custom-token imzalama yetkileri, yeni fonksiyonlar ve kuralları birlikte devreye alın; eski tetikleyicileri kaldırın.
6. Hocanın Apple Developer hesabı ile APNs, imzalama ve TestFlight yapılandırmasını tamamlayın.

Ayrıntılar ve ekran eşleştirmesi: **[Native iOS rehberi](native-ios/README.md)**.

Test kapsamı bütün olası hataları veya canlı ortam davranışlarını garanti etmez. Gerçek iPhone bildirimleri, Apple imzalama ve canlı veri geçişi ayrıca doğrulanmalıdır.
