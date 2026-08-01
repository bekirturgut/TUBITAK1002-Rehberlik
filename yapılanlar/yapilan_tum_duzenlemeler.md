# Projede Yapılan Tüm Düzenlemeler

Bu belge, proje üzerinde şimdiye kadar yapılan geliştirmeleri ve doğrulama çalışmalarını toplu olarak açıklamaktadır.

## 1. Android Derleme Altyapısı ve Sürüm Güncellemeleri

- Gradle Wrapper sürümü `8.14.3` olarak güncellendi.
- Android Gradle Plugin sürümü `8.11.1` olarak güncellendi.
- Google Services Gradle eklentisi `4.4.4` sürümüne yükseltildi.
- Güncel Flutter ve Android araçlarıyla uyumluluk kontrolleri yapıldı.
- Firebase eklentilerinin kendi Android yapılandırmalarından kaynaklanan Kotlin uyarısı incelendi. Bunun uygulama kaynak kodundan değil, kullanılan üst seviye eklentilerden gelen bir uyarı olduğu belirlendi.
- Android debug APK derlemesi kontrol edildi.

## 2. Oyun Kartlarının Çoktan Seçmeli Soru Sistemine Dönüştürülmesi

- Oyun kartları soru-cevap biçiminden dört seçenekli teste dönüştürüldü.
- Kartın ön yüzünde soru, arka yüzünde ise `A`, `B`, `C` ve `D` seçenekleri gösteriliyor.
- Doğru seçenek kartın kendi cevabından oluşturuluyor.
- Diğer üç yanlış seçenek, veri tabanındaki başka kartların cevaplarından rastgele seçiliyor.
- Böylece yanlış seçenekler için veri tabanında ek cevap alanları tutma ihtiyacı kaldırıldı.
- Seçeneklerin sırası her kartta karıştırılıyor.
- Aynı cevabın seçeneklerde tekrarlanmasını engelleyen kontroller eklendi.
- Kullanıcı seçim yaptıktan sonra doğru cevap yeşil, seçilen yanlış cevap kırmızı olarak belirtiliyor.
- Cevap sonucuna göre kullanıcıya doğru veya yanlış geri bildirimi gösteriliyor.

İlgili ana dosya: `lib/Pages/LearnPage.dart`

## 3. Kullanıcı Soru İlerlemesinin Firebase'e Kaydedilmesi

- Kullanıcının cevapladığı kartlar Firebase üzerinde kullanıcıya özel olarak kaydediliyor.
- Doğru ve yanlış cevap durumları güncelleniyor.
- Her kart için son cevap zamanı ve cevap durumu tutuluyor.
- Yanlış cevaplanan kartlar kullanıcının `wrongCards` alt koleksiyonuna ekleniyor.
- Daha önce yanlış cevaplanıp sonradan doğru bilinen kartlar yanlışlar listesinden çıkarılıyor.
- Kullanıcının toplam cevaplanan, doğru bilinen ve yanlış bilinen soru sayıları hesaplanıyor.

İlgili servis: `lib/services/quiz_progress_service.dart`

## 4. Normal Sorular ve Yanlış Soruları Tekrar Çözme Modu

- Oyun kartları ekranına iki ayrı çalışma modu eklendi:
  - Normal sorular
  - Önceden yanlış bilinen sorular
- Mod seçim ekranında kullanıcının tekrar çözmesi gereken yanlış soru sayısı gösteriliyor.
- Yanlış sorular modu yalnızca kullanıcıya ait yanlış kartları yüklüyor.
- Yanlış bilinen bir soru tekrar doğru cevaplandığında yanlışlar listesinden kaldırılıyor.
- Yanlış soru sayısının ekranlar arasında güncel kalması sağlandı.

## 5. Yanlış Soruların Bulunamaması Hatasının Düzeltilmesi

- Ana ekranda yanlış soru sayısı görünmesine rağmen yanlış sorular modunun boş açılması sorunu incelendi.
- Yanlış kart kayıtları ile mevcut oyun kartlarının kimlikleri eşleştirildi.
- Geçerli yanlış kart kimliklerinin yükleme sırasında korunması sağlandı.
- Yanlış sorular moduna girildiğinde kayıtların Firebase'den yeniden okunması eklendi.
- Böylece ekranda görünen yanlış soru sayısı ile tekrar çözülecek soru listesi uyumlu hale getirildi.

## 6. Rozet Sistemi

- Kullanıcının kendisine tanımlı sorulardaki başarı yüzdesi hesaplanıyor.
- Başarı oranlarına göre dört rozet seviyesi oluşturuldu:
  - `%25 Bilgi Ustası`
  - `%50 Bilgi Ustası`
  - `%75 Bilgi Ustası`
  - `%100 Bilgi Ustası`
- Kazanılan rozetler kullanıcının Firebase verilerinde saklanıyor.
- Kullanıcının kazandığı en son rozet ana ekranda gösteriliyor.
- Sağ üst bölümde kazanılmış rozetlere erişim sağlandı.
- Rozet alanına basıldığında kazanılan rozetlerin mesaj paneli biçiminde görüntülenmesi sağlandı.
- Rozet özeti hem anne kullanıcı hem de üst kullanıcı ekranına eklendi.

İlgili dosyalar:

- `lib/widgets/user_badge_summary.dart`
- `lib/services/quiz_progress_service.dart`
- `lib/Pages/MotherPage.dart`
- `lib/Pages/UpperPage.dart`

## 7. Chatbot ve Gemini Cevap Düzenlemesi

- Benzerlik eşiğini geçen bir veya birden fazla eşleşmiş cevap Gemini'ye gönderiliyor.
- Eşleşen cevaplarla birlikte kullanıcının asıl sorusu da Gemini isteğine eklendi.
- Gemini'nin sıfırdan yeni bir bilgi veya cevap üretmemesi için yönlendirme metni düzenlendi.
- Gemini yalnızca veri tabanında eşleşen cevapları kullanıcının sorusuna uygun, anlaşılır ve tek bir cevap hâline getiriyor.
- Tek eşleşme olduğunda da hem kullanıcı sorusu hem eşleşen soru-cevap kaydı gönderiliyor.
- Birden fazla eşleşmede cevaplar kullanıcının bağlamına göre birleştiriliyor.
- Gemini geçici olarak cevap oluşturamazsa en iyi eşleşen veri tabanı cevabının kaybolmaması için geri dönüş mekanizması korundu.
- Bu Cloud Functions değişiklikleri yerel proje kodunda yapıldı; ayrıca bir canlı ortama dağıtım işlemi yapılmadı.

İlgili dosya: `functions/index.js`

## 8. Sayfa Geçiş ve Giriş Animasyonları

- Uygulama genelinde yumuşak sayfa geçişleri eklendi.
- Ekran açılışlarında saydamlık ve hafif kayma efektleri uygulandı.
- Başlık, görsel, kart ve butonlara kademeli giriş animasyonları eklendi.
- Oyun modu kartları ve cevap seçeneklerinin sırayla görünmesi sağlandı.
- Ortak animasyon davranışları merkezi bir bileşende toplandı.

## 9. Oyun Kartı Çevirme Animasyonu

- Soru kartının ön ve arka yüzü arasına üç boyutlu çevirme animasyonu eklendi.
- Kart dönüşünde doğal görünmesi için perspektif etkisi kullanıldı.
- Cevap seçeneklerinin görünümü kart çevirme hareketiyle uyumlu hâle getirildi.

## 10. Hareketli Arka Plan ve Ortam Animasyonları

- Arka plana yavaşça hareket eden pastel renkli ışık katmanları eklendi.
- Aşağıdan yukarı süzülen hafif beyaz parçacıklar oluşturuldu.
- Giriş ekranındaki logoya yumuşak yukarı-aşağı süzülme hareketi eklendi.
- Anne ve üst kullanıcı ekranlarındaki kalp görsellerine süzülme ve hafif eğilme efekti uygulandı.
- Hareketli arka plan giriş, anne kullanıcı, üst kullanıcı ve oyun kartları ekranlarına eklendi.
- Arka plan animasyonları kullanıcı dokunuşlarını engellemeyecek şekilde yapılandırıldı.
- Animasyonların yeniden çizim alanı diğer arayüzden ayrılarak performans yükü sınırlandırıldı.
- Cihazın animasyonları azaltma veya kapatma tercihi desteklendi.

İlgili ana dosya: `lib/widgets/app_animations.dart`

## 11. Yapılan Test ve Doğrulamalar

- Düzenlenen Dart dosyalarında biçimlendirme çalıştırıldı.
- Yeni animasyon bileşeni statik analizden hatasız geçti.
- İlgili sayfalarda statik analiz yapıldı; yapılan düzenlemelerden kaynaklanan yeni bir derleme hatası görülmedi.
- Mevcut Flutter testlerinin tamamı başarıyla geçti.
- Debug APK başarıyla oluşturuldu.
- APK açık emülatörlerden birine başarıyla kuruldu.
- Uygulama emülatörde açıldı.
- Açılış loglarında kritik Flutter hatası, Dart hatası veya Android çökmesi görülmedi.

## 12. Başlıca Eklenen veya Düzenlenen Dosyalar

- `android/gradle/wrapper/gradle-wrapper.properties`
- `android/settings.gradle.kts`
- `lib/main.dart`
- `lib/Pages/LoginPage.dart`
- `lib/Pages/MotherPage.dart`
- `lib/Pages/UpperPage.dart`
- `lib/Pages/LearnPage.dart`
- `lib/services/quiz_progress_service.dart`
- `lib/widgets/user_badge_summary.dart`
- `lib/widgets/app_animations.dart`
- `functions/index.js`

