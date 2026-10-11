# Android yayın imzası ve release derlemesi

11 Ekim 2026. Kapsam yalnızca Android yayın imzası ve release paketinin teknik doğrulamasıdır.

## İmzalama

`android/app/build.gradle.kts`, yayın sürümlerinde `android/key.properties` içindeki upload anahtarını kullanır. Debug anahtarına geri dönüş kaldırıldı. Debug derlemelerin standart imzası devam eder.

Bu bilgisayarda oluşturulan özel dosyalar:

- Anahtar: `C:\Users\bekir\.android-signing\tubitak-rehberlik\upload-keystore.jks`
- Yerel Gradle ayarları: `android/key.properties`
- Ayarların ikinci kopyası: `C:\Users\bekir\.android-signing\tubitak-rehberlik\key.properties`

Anahtar RSA 2048, alias `upload`, geçerlilik 10000 gündür. Şifre rastgele oluşturuldu; bu belgeye veya Git'e eklenmedi. Özel dizinin ve yerel ayar dosyasının Windows erişim izinleri mevcut kullanıcıyla sınırlandırıldı. Android `.gitignore` kuralları anahtar ve `key.properties` dosyasını dışlar. Güvenli bir harici konuma hem anahtarın hem ayar dosyasının yedeğini alın; aynı bilgisayardaki ikinci kopya cihaz kaybına karşı yedek değildir.

Başka bilgisayarda `android/key.properties.example` dosyasını `key.properties` olarak kopyalayın; mevcut upload anahtarını taşıyıp yolları ve şifreleri yerel olarak girin. Her derlemede yeni anahtar oluşturmayın. Play Console'da Play App Signing kullanıldığında bu anahtar yükleme anahtarıdır; kullanıcılara dağıtılan uygulamanın imzası Google tarafından yönetilebilir.

## Derleme

Android SDK lisansları tamamlandı. Kurulu Flutter 3.44.2, API 36 ve NDK 28.2.13676358 kullanıyor; Android Gradle Plugin 8.11.1.

Eski Android Studio Java kurulumunun eksik `awt` kütüphanesi release lint aşamasını durdurdu. Yeni Android Studio Java 25 içerdiği için mevcut Gradle 8.14.3 ile uyumlu kurulu Temurin JDK 17 seçildi. Flutter'ın bu bilgisayardaki JDK ayarı `C:\Program Files\Eclipse Adoptium\jdk-17.0.17.10-hotspot` konumuna yönlendirildi. `flutter doctor -v` Android araç zinciri ve lisanslar için sorun bildirmedi.

Proje kökünde:

```powershell
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`.

Paket kimliği `com.tubitak.tubitak`; sürüm `1.0.0`, versionCode `1`. Sonraki mağaza yüklemelerinde versionCode artırılmalıdır.

## Doğrulama

Son release derlemesi başarılı: `flutter build appbundle --release` (133,2 saniye). AAB boyutu 58.773.154 bayt (56,1 MiB).

- Bundletool 1.18.3 paket doğrulaması: başarılı.
- JAR imza doğrulaması ve oluşturulan upload sertifikasıyla eşleşme: başarılı.
- Üretilen manifest: hedef API 36; debuggable yayın paketi değil.
- AAB paketleme isteği: `PAGE_ALIGNMENT_16K`.
- arm64-v8a ve x86_64 içindeki altı native kütüphane: LOAD hizalamaları en az 16 KB; RELRO'nun 16 KB sayfalara yuvarlanması yazılabilir verilerle çakışmıyor. RELRO'nun tüm LOAD segmentini kapsadığı durumlar yalnızca bitiş adresi üzerinden reddedilmez.
- AAB'den oluşturulan imzalı universal APK: `zipalign -c -P 16 -v 4` başarılı.
- AAB SHA-256: `d5df1b1d267cd7ed44a66da0883dea7564af232d559c0e812da097aa00ff9d16`.

Teknik kontrol kayıtları `build/release-verification/` altındadır ve Git'e eklenmez. İmza, upload sertifikası eşleşmesi, manifest, bundletool doğrulaması, AAB ZIP hizalama isteği, 64 bit ELF LOAD/RELRO hizalamaları ve AAB'den üretilen APK'nin `zipalign -c -P 16` sonucu kontrol edilir.

Gerçek cihazda veya 16 KB Android emülatöründe çalışma testi bu kapsamda yapılmadı. Teknik paket kontrolü mağaza incelemesinin veya çalışma testinin yerine geçmez.

Resmî kaynaklar: [Flutter Android yayın rehberi](https://docs.flutter.dev/deployment/android), [Android 16 KB rehberi](https://developer.android.com/guide/practices/page-sizes).
