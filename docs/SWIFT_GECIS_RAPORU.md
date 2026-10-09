# Swift istemcisi: mevcut akışa dönüş

Tarih: 9 Ekim 2026. Dal: `migration/native-swift`.

Kullanıcının isteğiyle Swift dönüşümü sırasında eklenen backend/Auth mimarisi geri alındı. Önceki rapordaki Auth geçişi, kullanıcı/şifre taşıması, yeni kurallar ve embedding backfill adımları artık uygulanmamalıdır; ilgili araçlar kaldırıldı.

## Geri alınanlar

- Firebase Auth/custom token, scrypt özel şifre depoları ve telefon indeksleri.
- Sunucuda quiz değerlendirme ve yeni quiz deneme koleksiyonu.
- Native kullanıcı/mesaj/cihaz/geri bildirim uç noktaları.
- Yeni bot iş kuyruğu, cihaz kayıt koleksiyonu ve yeni bildirim zamanlayıcı mimarisi.
- Oturum sürümü, hesap kapatma ve genişletilmiş kullanıcı silme davranışı.
- Yeni Firestore güvenlik kuralları/indeks dağıtımı ve tüm veri taşıma/backfill araçları.

`functions/package.json`, `functions/package-lock.json` ve `firebase.json` dosyaları `e445e39` ile aynıdır. Backend işleyişi eski sürümdür; yalnızca Firebase Admin SDK uyumluluğu için FieldValue/Timestamp doğrudan firestore modülünden alınır. Flutter `lib/` kaynakları değiştirilmedi. Swift telefon/şifre, profil, quiz, sohbet ve bildirim akışları bu eski kaynaklara uyarlanmıştır. Yeni Gemini anahtarı yerelde eski backend'in okuduğu ve Git'in yok saydığı `.env` dosyasında tutulur. Secret Manager kaydı korunur; eski backend Secret Manager'a bağımlı değildir.

## Doğrulama

Doğrulanan kod: `306ad102d2f7e513ec0ebae868e43daccfa55dff`. [GitHub Actions çalışması](https://github.com/bekirturgut/TUBITAK1002-Rehberlik/actions/runs/37898717007) hem backend hem Swift/iOS işi için başarılıdır.

| Kontrol | Sonuç |
| --- | --- |
| Orijinal kaynak/config eşitliği ve yeni Auth bağımlılıklarının kaldırılması | 7/7 geçti |
| İzole Firestore/Functions emülatöründe eski veri akışı | 12/12 geçti |
| Swift çekirdek: telefon, hafta, quiz seçenekleri, oran ve rozetler | 11/11 geçti |
| iOS model ve gerçek Swift/Firestore kullanıcı işlemleri | 4/4 geçti |
| iOS ekranları ve gerçek emülatör giriş–quiz–uzman sohbeti | 5/5 geçti |
| Fiziksel iPhone hedefi için imzasız Release derlemesi | Başarılı |

Toplam 39 ayrı test/kontrol geçti; XCTest ve kaynak uyumluluk testlerinde atlanan test yoktur. Backend emülatör kontrolleri ayrıca macOS işinde de çalıştırıldı. Önceki Auth mimarisine ait 49 test sonucu bu sürüm için kullanılmamıştır.

Swift/Firestore testi kısa mevcut şifreyle kullanıcı oluşturmayı, şifreyi değiştirmeden düzenlemeyi, yanlış şifre/rol reddini, giriş geçmişini, yanlış→doğru quiz kaydını, %25 rozetini, çıkışı ve eski kullanıcı silme kapsamını doğruladı. Ekran testi annenin giriş ve quiz akışını, uzman yönlendirmesini, admin yanıtını ve bu yanıtın anneye ulaşmasını tamamladı.

İlk test çalışmasındaki Firebase kurulum hatası giderildi: emülatör için kilitlenmiş mevcut Firebase seçeneklerinin kopyası değiştirilmek yerine ayrı bir yapılandırma oluşturulur. Bu değişiklik test dosyasındadır; üretim giriş akışını değiştirmez.

Yeni Gemini anahtarı eski backend'in kullandığı SDK üzerinden model listeleme isteğiyle doğrulandı. Emülatör testlerinde Gemini ve push gönderimi taklit edilir; bu testler veri akışını doğrular, gerçek model yanıt kalitesini veya APNs teslimini kanıtlamaz.

Canlı dağıtım veya gerçek kullanıcı verisi değişikliği yapılmadı. Gerçek Gemini cevabı, fiziksel iPhone/APNs ve Apple imzalama ayrı doğrulama gerektirir. İmzasız derleme cihazda çalıştırma veya TestFlight dağıtımı değildir. Otomatik kontrollerin geçmesi tüm olası hataların bulunmuş olduğunu garanti etmez.
