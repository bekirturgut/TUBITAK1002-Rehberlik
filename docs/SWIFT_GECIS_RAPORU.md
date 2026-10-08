# Swift geçişi ve doğrulama raporu

Tarih: 8 Ekim 2026. Çalışma dalı: `migration/native-swift`.

## Yapılan dönüşüm

iOS istemcisi `native-ios/` altında Swift/SwiftUI ile yeniden yazıldı. Uygulama Dart/Flutter çalışma zamanı kullanmıyor. Önceki Flutter kaynakları, karşılaştırma ve kontrollü geçiş için korunuyor. Firebase Cloud Functions sunucu kodu JavaScript olarak kalıyor; iOS istemcisinin Swift olması sunucunun dilinin değişmesini gerektirmiyor.

Anne, üst kuşak ve uzman rolleri; giriş/oturum, ana ekran, öğrenme kartları, yanlışları tekrar çözme, ilerleme/rozetler, SSS, bot/uzman sohbeti, bildirimler ve yönetim ekranları taşındı. Uzman kullanıcı, kart, SSS, bot bilgi tabanı ve bildirim şablonlarını yönetebilir; giriş geçmişini görebilir.

Swift çekirdeği, kullanıcı arayüzünden ve Firebase'den bağımsızdır. Rol, telefon, hafta hesabı, kart uygunluğu, dört farklı seçenek ve ilerleme/rozet hesabı burada test edilir. Firestore modelleri ve ekranlar ayrı dosyalardadır.

## Giderilen güvenlik ve veri akışı sorunları

- İstemcinin Firestore'dan açık şifre okuyarak giriş yapması kaldırıldı. Sunucuda scrypt doğrulaması ve Firebase Auth custom token kullanılıyor. Şifreler istemci tarafından okunamıyor.
- Rol ve kullanıcı kimliği sunucuda doğrulanıyor. Başka hesaba erişme, uzman kimliğini taklit etme ve ilerleme sonucu yazma engelleniyor. Şifre/rol değişimi eski oturumları geçersiz kılıyor.
- Telefonlar tek biçime dönüştürülüyor; aynı telefonla ikinci hesap oluşturulamıyor. Yönetici kendi yetkisini kaldıramıyor veya hesabını silemiyor.
- Quiz cevapları sunucuda değerlendiriliyor. Tekrar gönderim aynı deneme kimliğiyle çoğaltılmıyor. Doğru/yanlış kayıtları atomik değişiyor; eşzamanlı cevaplar kaybolmuyor. Silinmiş, pasif veya henüz açılmamış kartlar ilerlemeye dahil edilmiyor.
- Kart, kullanıcı cevap verirken değiştiyse eski sorunun cevabı yanlış olarak kaydedilmiyor. Eski içeriklerdeki baştaki/sondaki boşluklar istemci ve sunucuda aynı şekilde işleniyor.
- Sohbet mesajları tekrar denemede çoğalmıyor. Uzman yanıtı belirli bir soruya bağlanıyor ve gerçek uzman kimliğiyle saklanıyor. Eski sohbet dinleyicileri hesap/ekran değişiminde yeni ekrana veri taşıyamıyor.
- Bot servisi veya bağlantı başarısız olduğunda soru kaybolmuyor; tek uzman talebi oluşturuluyor. Arka plan tetikleyicileri ve süresi dolan işlerin kurtarılması, uygulama kapanınca da akışı sürdürüyor. Silinmiş soru için gelen eski olaylar tekrar döngüsüne girmiyor; yetim bot işleri bildirim zamanlayıcısını durdurmuyor.
- Güncellenen sorunun eski embedding'i kullanılmıyor. Boyutu uyuşmayan vektörler karşılaştırılmıyor. Embedding üretilemezse eski vektör kaldırılıyor.
- Bildirim kuyruğu gönderilmiş kaydı tekrar bekleyen duruma çevirmiyor. Tek kurulumun bir sahibi var; eski hesabın çıkışı yeni hesabın cihaz kaydını silemiyor. Bildirime dokunmak ilgili ekranı açıyor.
- Kullanıcı silme; alt koleksiyonları, sohbeti, cihazları, kuyrukları ve bot işlerini temizliyor. Yarım kalan silme yeniden denenebilir.
- Yönetim formlarındaki kayıt kimlikleri tekrar denemede korunuyor. Seçim ekranından geri dönmek düzenlenen alanları sıfırlamıyor. Form hataları ilgili formda gösteriliyor.
- Hatalı uygulama ikonu değiştirildi. Simülatör Firebase oturumu için ayrı Keychain yetkisi ve yerel imzalama eklendi; bunun için Apple hesabı gerekmez.

## Doğrulama

- Yerel backend birim testleri: **8/8 geçti**.
- Yerel Auth/Firestore emülatörü entegrasyon testleri: **24/24 geçti**.
- `npm audit` (geliştirme bağımlılıkları dahil): **0 bilinen açık**.
- macOS üzerinde iOS uygulaması derlendi; **3/3 model testi ve 5/5 arayüz/uçtan uca testi geçti**.
- macOS Swift çekirdek testleri: **9/9 geçti**.
- Gerçek callable HTTP protokolü, Auth token dönüşümü, quiz, bot/uzman ve cihaz uç noktaları: **yerelde ve macOS CI üzerinde geçti**.
- Simülatörde Firebase uçtan uca akışı: **geçti**.
- Toplam **49 otomatik test geçti**; HTTP smoke doğrulaması ayrıca başarılı.
- iPhone hedefi için imzasız Release derlemesi: **geçti**.
- GitHub Actions backend ve macOS işlerinin tamamı: **başarılı**.

Kaynak sürümü: `e7004cb`. [Doğrulama çalışması](https://github.com/bekirturgut/TUBITAK1002-Rehberlik/actions/runs/37772732809).

Entegrasyon testleri; erişim kuralları, rol/kimlik sahteciliği, hesap kapatma, oturum iptali, quiz tekrarları/eşzamanlılık, eski kart içeriği, sohbet/uzman yönlendirmesi, cihaz sahipliği, kullanıcı silme ve veri taşıma araçlarını kapsar. AI servis hatası kontrollü olarak taklit edilir; testler gerçek Gemini cevabının kalitesini ölçmez.

CI ayrıca gerçek SwiftUI istemcisini izole `demo-rehberlik` Auth/Firestore/Functions emülatörlerine bağlar: anne girişi, sunucuda cevap kaydı, sohbet, uzman yanıtı ve annenin yanıtı alması. Ekran testleri ve görüntü ekleri ayrı olarak saklanır.

Mevcut projedeki `gemini-2.5-flash` ve `gemini-embedding-001` modelleri korunmuştur. Google, 2.5 ailesini geçmişte aktif kullanmış projelerle sınırlıyor; yeni staging projesinde cevap modeline erişim ayrıca kontrol edilmelidir. [Google model yaşam döngüsü](https://ai.google.dev/gemini-api/docs/deprecations/). Model erişimi başarısızsa mevcut bilgi tabanı cevabı veya uzman yönlendirmesi kullanılır.

## Canlıya geçişte kalan işler

Canlı Firebase'e dağıtım veya canlı kullanıcı verisi değişikliği yapılmadı. Ana dal değiştirilmedi.

1. Git geçmişinde yer almış Gemini anahtarını sağlayıcıda iptal edip yenileyin. Dosyanın Git takibinden çıkarılması geçmişteki anahtarı iptal etmez.
2. Firestore yedeği alın; eski istemcide yazma işlemlerini kontrollü durdurun.
3. `functions/scripts/migrate-users.js` ve `migrate-notifications.js` araçlarını önce varsayılan dry-run modunda, sonra staging ortamında doğrulayın. `--apply` gerçek değişiklik yapar.
4. Yeni secret, Auth token imzalama yetkileri, fonksiyonlar, güvenlik kuralları ve indeksleri birlikte devreye alın. Eski zamanlayıcı/tetikleyicileri birlikte çalıştırmayın. Kullanıcı geçişi eski Flutter şifre girişini durdurur; eski Android istemcisi de uyarlanmalıdır.
5. `backfill-embeddings.js` ile bilgi tabanı vektörlerini yeni biçimde üretin; gerçek Gemini yanıtlarını ve uzman yönlendirmesini staging üzerinde inceleyin.
6. Hocanın Apple Developer hesabıyla imzalama/APNs/TestFlight ayarlarını tamamlayın. Gerçek iPhone üzerinde giriş, hesap değişimi, çevrimdışı/yeniden bağlantı ve uygulamanın açık/kapalı durumlarında bildirim teslimini doğrulayın.

Otomatik testler bütün olası hataların yokluğunu kanıtlamaz. Özellikle canlı IAM, veri geçişi, gerçek AI yanıtları ve fiziksel cihaz bildirimi ayrıca doğrulanmalıdır. İmzasız cihaz derlemesi iPhone'a kurulabilir dağıtım paketi değildir.
