# TÜBİTAK Aile Destek ve Öğrenme Platformu

Swift/SwiftUI iOS istemcisi `native-ios/` altındadır. Flutter kaynakları korunur.

**Mevcut projenin işleyişi korunur:** telefon/şifre kontrolü Firestore `users` üzerinden yapılır; Firebase Auth/custom token ve kullanıcı veri taşıması gerekmez. Quiz, kullanıcı yönetimi, sohbet ve bildirim kayıtları eski Flutter veri yapısıyla aynıdır. Sunucu akışı, bağımlılık kilidi ve canlı dağıtım yapılandırması dönüşüm öncesindeki `e445e39` sürümüne geri alınmıştır. Backend içinde yalnızca FieldValue/Timestamp SDK import uyumluluğu düzeltmesi vardır.

- [Swift istemcisi ve testler](native-ios/README.md)
- [Akış uyumluluğu ve doğrulama](docs/SWIFT_GECIS_RAPORU.md)
- [Önceki Flutter açıklaması](docs/FLUTTER_REFERENCE.md)

Gemini anahtarı Git'e dahil olmayan `functions/.env` dosyasında tutulur; Swift uygulamasına eklenmez. Canlı backend ve Firestore verisi bu değişiklikle dağıtılmaz/değiştirilmez.
