# Swift istemcisi: mevcut akışa dönüş

Tarih: 8 Ekim 2026. Dal: `migration/native-swift`.

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

Bu sürüme ait sonuçlar tamamlandıktan sonra burada kaydedilecektir. Önceki sürümün 49 test sonucu, geri alınmış Auth mimarisine aittir; bu sürümün kanıtı olarak kullanılamaz.

Yeni testler: orijinal dosya eşitliği ve Flutter kaynak kontrolü; izole Firestore/Functions emülatöründe eski callable payload'ları, quiz kayıtları, kullanıcı rolleri, uzman yanıtı/alert durumu ve eski token/kuyruk biçimi; macOS Swift çekirdek, model ve UI testleri; iPhone imzasız Release derlemesi.

Canlı dağıtım veya gerçek kullanıcı verisi değişikliği yapılmadı. Gerçek Gemini cevabı, fiziksel iPhone/APNs ve Apple imzalama ayrı doğrulama gerektirir.
