# İmzalı iOS dağıtımı ve silmeden güncelleme

Henüz ücretli Apple Developer üyeliği yoktur ve ilk iOS dağıtımı yapılmamıştır. Gerçek imzalı IPA/TestFlight sürümü üretilmedi. Kaynak kodda hazırlanan imzalama akışı, Apple hesabı ve sertifikası sağlandıktan sonra çalıştırılabilir.

Uygulama kimliği `com.tubitak.tubitak` olarak korunur. İlk dağıtımdan sonraki güncellemeler aynı App Store Connect uygulama kaydına, aynı geliştirici ekibi altında gönderilmelidir. Yeni uygulama kaydı veya farklı bundle ID ile dağıtım yapmak yerine mevcut uygulamaya yeni build yüklenir. Sertifikalar süreleri dolduğunda aynı ekip altında yenilenebilir; aynı sertifikayı sonsuza kadar kullanmak gerekmez.

## Sırasıyla yapılacaklar

1. Hocanın Apple hesabıyla [Apple Developer Program üyeliği](https://developer.apple.com/programs/enroll/) başlatılır. Apple'ın standart ücreti yıllık 99 USD'dir; yerel ücret/vergiler kayıt ekranından kontrol edilir. Hesabın sahibi üyelik ve sözleşme işlemlerini tamamlar. [Üyelik açıklaması](https://developer.apple.com/help/account/membership/program-enrollment/)
2. Üyelik aktif olunca Team ID alınır. Certificates, Identifiers & Profiles bölümünde `com.tubitak.tubitak` için açık App ID kaydedilir ve Push Notifications etkinleştirilir. Bu kimlik daha önce başka ekip tarafından alınmışsa yeni kimlik seçimi ve Firebase iOS kaydı birlikte ele alınmalıdır; kaynakta tek başına değiştirilmemelidir.
3. Apple Distribution sertifikası, ona ait özel anahtarla birlikte parolalı `.p12` olarak hazırlanır. Aynı sertifika ve App ID için **App Store Connect distribution provisioning profile** oluşturulur. Development/ad hoc profile bu akışta kullanılmaz. Sertifika/anahtar sohbete veya Git'e eklenmez.
4. GitHub deposunda Settings → Secrets and variables → Actions altında aşağıdaki alanlar tanımlanır. Dosyaların Base64 biçimi tek satır olmalıdır.

| Tür | Ad | Değer |
| --- | --- | --- |
| Variable | `APPLE_TEAM_ID` | 10 karakterli Apple Team ID |
| Secret | `APPLE_DISTRIBUTION_P12_BASE64` | Özel anahtarı içeren `.p12` dosyasının Base64 biçimi |
| Secret | `APPLE_DISTRIBUTION_P12_PASSWORD` | `.p12` parolası |
| Secret | `APPLE_APPSTORE_PROFILE_BASE64` | App Store distribution `.mobileprovision` dosyasının Base64 biçimi |

Windows'ta Base64 metnini terminale yazdırmadan panoya almak için PowerShell kullanılabilir:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\imzalama\distribution.p12')) | Set-Clipboard
```

5. `native-ios-signed.yml` varsayılan dalda yer aldığında GitHub Actions → **Signed iOS App Store archive** → Run workflow seçilir; doğrulanmış kaynak dalı ve sürüm numarası belirtilir. GitHub manuel çalıştırma düğmesi için workflow dosyasının varsayılan dalda bulunmasını gerektirir. Şu an dosya `migration/native-swift` dalındadır; ana dala otomatik birleştirme yapılmadı. [GitHub açıklaması](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
6. İş macOS/Xcode üzerinde gerçek dağıtım imzasıyla archive ve IPA üretir. Profilin ekip, bundle ID, süre, dağıtım türü ve üretim push yetkisi kontrol edilir. IPA, yedi gün saklanan `signed-ios-...` artifact'inden alınır. Bu App Store IPA'sı doğrudan iPhone'a kurulmaz; App Store Connect'e yüklenmelidir. Mevcut workflow **otomatik yükleme veya mağazada yayınlama yapmaz**. Hesap açıldıktan sonra App Store Connect uygulama kaydı ve buluttan yükleme yetkisi ayrıca yapılandırılır.
7. İlk deneme dağıtımı TestFlight ile yapılır; kullanıcılar sonraki build'i TestFlight üzerinden günceller. Beta build'leri 90 gün geçerlidir. Uzun süreli dağıtım için aynı uygulama kaydıyla App Store yayını hazırlanır. [TestFlight açıklaması](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
8. Firebase'deki mevcut iOS uygulamasına Apple APNs anahtarı bağlanır. Gerçek iPhone'da giriş, mevcut kurulumun üzerine güncelleme ve açık/kapalı uygulamaya bildirim teslimi sınanır. Bu işlemler Firestore giriş veya backend veri akışını değiştirmez.

Yeni workflow güncel App Store SDK gereksinimini karşılamak için `macos-26` kullanır ve iOS SDK sürümünün en az 26 olduğunu doğrular. Daha önce geçen Xcode 16.4 testleri kaynak/akış doğrulamasıdır; bugünkü mağaza yükleme yeterliliğinin kanıtı değildir. [Apple SDK gereksinimi](https://developer.apple.com/news/?id=ueeok6yw)

Sonraki güncellemede aynı bundle ID ve App Store kaydı korunur. Workflow her çalışmada build numarasını artırır; kullanıcıya görünen sürüm numarası gerektiğinde Run workflow ekranından yükseltilir. Oturum ve Firestore verisi güncelleme için silinmez.
