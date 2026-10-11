# Chatbot ve bekleyen soru düzeltmeleri

10 Ekim 2026

## Doğrulanan sorun

Canlı `askFaqBot` uç noktası kişisel veri içermeyen, kullanıcı ID'siz bir deneme sorusunda HTTP 500 / INTERNAL (`Bot çalışırken hata oluştu`) döndürdü. Açık Flutter uygulamasının günlüğünde de aynı callable hatası görüldü. Firebase girişi sonrasında canlı günlüklerden sunucudaki Gemini anahtarının geçersiz olduğu doğrulandı (`API_KEY_INVALID`). Aynı projedeki mevcut Gemini anahtarı bulundu; bu anahtar için de servis HTTP 402 `RESOURCE_EXHAUSTED` / ön ödeme kredisi tükenmiş yanıtı verdi. Kullanıcı krediyi AI Studio üzerinden yükleyeceğini bildirdi.

## Yapılanlar

- Flutter artık bot hatasını kullanıcıya gösteriyor. Soruda hata durumu kaydediliyor ve sohbet içinde yeniden deneme düğmesi sunuluyor. Aynı kaynak mesaj kullanılıyor; yeniden deneme ikinci kullanıcı sorusu oluşturmuyor. Bot cevabı kaynak mesajdan türetilen tek belgeye yazılıyor; mevcut başarılı yanıt tekrar istenmiyor.
- Sunucu önce aktif bilgi tabanını kontrol ediyor. Boş bilgi tabanı için gereksiz Gemini çağrısı kaldırıldı. Embedding servisi hata verdiğinde tam eşleşen bilgi tabanı cevabı kullanılabiliyor; başka güvenilir eşleşme yoksa soru uzman desteğine yönlendiriliyor. AI istekleri 20 saniyeyle ve tek denemeyle sınırlandı.
- Bekleyen soru sayacı sohbet özetindeki `hasPendingAdminReply` alanına güvenmek yerine canlı mesajları kontrol ediyor. Gerçek kullanıcı sorusu olmayan/boş kayıtlar, cevaplanmış veya uzman cevabı referansı olan sorular ve silinmiş kullanıcıların sohbetleri sayılmıyor. Sorgu hatası sıfır soru olarak gösterilmiyor.
- Uzman cevabı ve sorunun cevaplandı durumu tek Firestore batch'inde kaydediliyor. Tek bekleyen soru varsa yazılan cevap otomatik ilişkilendiriliyor; birden çok soru varsa uzman hangi soruyu cevapladığını seçiyor.
- Sunucunun bekleyen durumunu ve cevaplanan uyarıları güncelleyen sorgularının birleşik indeks bağımlılığı kaldırıldı. Silinmiş bir soruya yönlendirme boş/yanıltıcı mesaj oluşturmuyor. Cevaplanmış soru geç gelen geri bildirimle tekrar beklemeye alınmıyor.

## Kontroller

- Flutter: giriş ekranı testi ve üç bekleyen soru testi başarılı.
- Firebase demo emülatörü: 15 entegrasyon kontrolü başarılı. Gerçek Firebase verilerine veya gerçek Gemini servisine yazılmaz; AI/FCM test doubles kullanılır.
- Backend uyumluluk kontrolü: altı test başarılı; mevcut dışa açılan işlevler, bağımlılık kilidi, Firebase yapılandırması ve native istemcinin mevcut bağlantı sözleşmesi korunuyor. Önceki byte düzeyinde değişmezlik testleri kullanıcının istediği chat düzeltmelerine izin verecek şekilde güncellendi.
- Statik analiz: derleme hatası yok; projede önceden mevcut uyarı/bilgi seviyesindeki kayıtlar sürüyor.

## Canlıya alma

Firebase hesabına giriş tamamlandı. Mevcut Gemini anahtarı gizli ortam dosyasına aktarıldı ve beş ilgili işlev canlıya alındı. Canlı uç nokta iki farklı soru ifadesinde HTTP 200 ve dolu cevap döndürdü. Sonraki doğrudan API testinde embedding ve güncel modelle metin üretimi başarıyla çalıştı; kredi hatası bu testlerde tekrar görülmedi. Kullanıcı Apple Developer üyeliği/imzalama ve App Store metadata/URL hazırlığını şimdilik erteledi. İki iOS istemcisinin 1024×1024 mağaza ikonları dahil iOS ikonlarının alfa kanalları kaldırıldı.

Canlı günlükler ve mevcut Gemini yapılandırması kontrol edildi. Doğru anahtar projeye özel, Git tarafından yok sayılan `functions/.env.tubitak-86d68` dosyasında korunuyor. İlk yayında kullanılan temel komut:

```sh
npx --yes firebase-tools@15.30.0 deploy --project tubitak-86d68 --only functions:askFaqBot,functions:escalateChatToAdmin,functions:onAdminReplyResolveAlert
```

İlk yayın `onCreateFaqEmbedding` ve `onUpdateFaqEmbedding` işlevlerini de kapsadı; beş güncelleme başarılı. Canlı testi kullanıcı ID'siz bilgi tabanı sorularıyla yapıldı; test amaçlı insanlara bildirim veya canlı sohbet mesajı gönderilmedi. Uzman cevaplama akışı demo emülatöründe doğrulandı.

Canlı sayaç denetimi: 5 sohbet içinde eski özette 2 bekleyen kullanıcı görünürken gerçek bekleyen kullanıcı sayısı 0 idi. Bir eski işaret ve silinmiş kullanıcıya ait bir özet, belge güncelleme zamanı önkoşuluyla temizlendi; mesaj içeriği değiştirilmedi. Aktif 185 FAQ kaydının tamamında 3072 boyutlu eşleştirme vektörü bulunuyor.

Ek bulgu: `gemini-2.5-flash` bu projede metin üretiminde `Not Found` döndürdü. Aynı anahtarla `gemini-3.5-flash-lite` metin üretimi başarılı oldu. Formatter varsayılanı bu güncel modele geçirildi; istenirse `GEMINI_FAQ_MODEL` ortam değişkeni ile seçilebilir. Eşleştirme modeli aynı kaldığından mevcut 185 FAQ vektörünün yeniden üretilmesi gerekmiyor. Google eski 2.5 erişimini önceki aktif projelerle sınırladığını ve güncel model kullanılmasını önerdiğini açıklıyor: [resmî model belgesi](https://ai.google.dev/gemini-api/docs/models). Model değişikliği sonrası altı backend sözleşme ve 15 demo entegrasyon kontrolü tekrar başarılı.

Son doğrulama: güncel formatter modeli için ikinci `askFaqBot` yayını da tamamlandı. Tam FAQ sorusu HTTP 200 / 194 karakter cevap, farklı ifadeli soru HTTP 200 / 230 karakter cevap döndürdü; her ikisinde eşleştirme başarılı, uzman yönlendirmesi gerekmedi. Bu canlı testlerden sonra günlüklerde embedding/cevap düzenleme/callable hatası bulunmadı. Canlı sayaç yeniden okundu: eski özet ve gerçek mesaj hesabı birlikte 0 bekleyen kullanıcı gösteriyor.
