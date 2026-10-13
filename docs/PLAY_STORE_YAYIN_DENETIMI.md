# LactiGen yayın denetimi — 13 Ekim 2026

Android paketi: `build/releases/LactiGen-1.0.2+3.aab`. Paket adı `com.tubitak.tubitak` korundu. Marka: **LactiGen**, alt başlık: **Akıllı Emzirme Asistanı**.

## Giderilen sorunlar

| Bulgu | Yapılan düzeltme |
|---|---|
| Canlı Firestore herkese okuma/yazma izni veriyordu | Kimlik doğrulama ve kullanıcı sahipliği zorunlu. Yönetici yetkisi sunucudaki profilden doğrulanır. Anonim özel veri erişimi canlı ortamda 403 ile reddedildi. SSS kamuya açık kaldı. |
| Şifreler profilde açık metin tutuluyordu | Dört profil kendi UID ve mevcut şifresi korunarak Firebase Authentication'a aktarıldı. Açık metin alanlar kaldırıldı. Hatırlanan oturum Auth üzerinden doğrulanır. |
| Kullanıcı oluşturma/silme istemcide yapılıyordu | Yalnız gerçek yöneticinin çağırabildiği sunucu işlevleri eklendi. Silme; Auth hesabını, profil alt koleksiyonlarını, sohbeti, kuyruk ve başvuruları kapsar. Silme sürerken erişim kapatılır. |
| AI yanıtları istemciden yazılabiliyordu | Yanıtı sunucu oluşturur ve kaydeder. Kaynak soru, kullanıcı sahipliği ve güncel AI izni doğrulanır. Bot taklidi engellenir. |
| Uygunsuz AI içerik bildirimi yoktu | Bot yanıtlarına bildirme seçeneği ve yönetici inceleme ekranı eklendi. |
| Hesap/veri silme yöntemi görünür değildi | Uygulamada silme talebi, web sayfasında e-posta başvurusu ve Console'da ilgili bağlantı eklendi. Talep anında silme değildir; yönetici kimlik doğrulamasından sonra siler. |
| Gizlilik metni güncel işleyişle uyumsuzdu | Uygulama ve web metni güncellendi. İletişim, 1 yıl saklama, Firebase, Gemini, IP kaynaklı yaklaşık konum, bildirim, ayrı AI izni ve silme açıklanıyor. |
| Sağlık beyanında araştırma seçilmişti | Kullanıcı yalnız eğitim/destek kullanılacağını doğruladı. Araştırma, stres yönetimi ve kamu sağlığı seçimleri kaldırıldı; tıbbi referans/eğitim ve üreme sağlığı seçildi. Araştırma ifadeleri kaldırıldı. |
| Finans beyanında “Diğer” seçilip finans özelliği olmadığı yazılmıştı | Yanlış seçim kaldırıldı ve doğrudan “Uygulamamda finans ile ilgili özellik sağlanmıyor” seçildi. |
| IARC anketinde kullanıcı paylaşımları ana içerik ve davet edilen arkadaşlarla sınırlandırma seçilmişti | Kullanıcının IARC şartlarını kabul etme onayıyla yeni anket hazırlandı. Ana içerik kullanıcı paylaşımı değil; arkadaş daveti yok. Eğitim ve çevrim içi/AI içerik, destek görevlisiyle metin iletişimi doğru kapsamda beyan edildi. |
| Veri güvenliği formu işleyişi kapsamıyordu | Kişisel bilgiler, sağlık içeriği, mesajlar, uygulama etkileşimleri/diğer kullanıcı içeriği, cihaz kimlikleri ve SDK kaynaklı yaklaşık konum kapsamı düzeltildi. Aktarımda şifreleme ve silme yöntemi açıklandı. |
| Çıkıştan sonra bildirim belirteci kalabiliyordu | Belirteç ve dinleyiciler temizlenir; sunucu kuyruk belirtecini güncel profille karşılaştırır. Otomatik bildirim başlangıcı kapatıldı ve izin kontrolü eklendi. |

Gemini için soru aktarımı ayrı, isteğe bağlı izin gerektirir. Ad, telefon veya UID ayrıca AI isteğine eklenmez; kullanıcı bunları soruya yazarsa aktarılabilir. Tıbbi cihaz olmadığı ve sağlık profesyoneline başvurma uyarısı sohbet ve mağaza açıklamasında bulunur.

## Doğrulama

- Flutter: **8 test geçti**.
- Firestore/Auth emülatörleri: **6 güvenlik ve hesap yönetimi testi geçti**.
- Gerçek AI callable kodu sahte AI sağlayıcısıyla izole emülatörde: **2 test geçti**. Kimlik/izin/soru sahipliği reddi, sunucuda yanıt kaydı ve tekrarda çift mesaj oluşmaması doğrulandı. Gerçek kullanıcı verisi AI sağlayıcısına gönderilmedi.
- Release AAB; bundle doğrulaması, upload imzası, API 36 hedefi, 16 KB native ELF/RELRO ve üretilen APK ZIP hizalaması kontrollerini geçti.
- AAB SHA-256: `dc84b20309d6705628fa969d7b39345277cad771d9e1d2401f2f821e81ac5a7d`. 16 KB cihazda çalışma testi yapılmadı; doğrulama dosya ve hizalama düzeyindedir.
- Android emülatöründe mevcut demo anne hesabıyla yeni Auth girişi ve eski eğitim/sohbet kayıtlarına erişim doğrulandı. Gizlilik ve içerik bildirme ekranları görüldü.
- Kullanıcının düzelttiği mevcut yönetici şifresiyle Android'de yönetici girişi ve içerik/silme talepleri paneli doğrulandı. Şifre değişikliği yapılmadı.
- Canlı anonim Firestore kullanıcı erişimi 403, anonim AI callable isteği 401 ile reddedildi.
- `flutter analyze`: derleme hatası yok; 29 bilgi düzeyi lint ve önceki NotificationPage'deki kullanılmayan değişkene ilişkin 1 uyarı var. Yayın paketi başarıyla derlendi.

Kanıtlar: `build/policy-audit/`, `build/policy-tests/`, `build/release-verification/report.json`. Kimlik bilgileri rapora yazılmadı.

## Yayın durumu

1.0.2 (versionCode 3), mağaza açıklaması, sağlık, veri güvenliği, finans ve yeni IARC anketi Play Console'a kaydedildi ve inceleme isteği gönderildi. Önceki inceleme bu güncellemelerle yeniden başlatıldı. Son görünür durumda henüz gönderilmeyen değişiklik kalmadı. Console **İncelenmekte olan değişiklikler** altında **LactiGen 1.0.2** gösteriyor; otomatik hızlı kontroller devam ediyor. Türkiye, tam kullanıma sunum. Yönetilen yayınlama kapalı. Google inceleme sonucu henüz alınmadı. Kanıt: `build/policy-audit/play-submitted-1.0.2.png`.

Yeni IARC sonucu: Türkiye/dünyanın geri kalanı için 3+, PEGI 3, diğer ilgili bölgelerde tüm yaşlar. Bu bir içerik derecelendirmesidir; mağaza hedef kitlesi 18 ve üzeri olarak korunmuştur. Eğitim dışı madde referansı kontrolü için mevcut 187 FAQ, 22 SSS, 29 anne kartı ve 11 üst kuşak kartı incelendi; bu referanslar bulunmadı.

Google'a yalnız çalışan anne demo hesabı ve İngilizce kullanım talimatları sunuldu. Kullanıcı yönetici bilgilerinin Google incelemesine eklenmemesini istedi; yönetici hesabı paylaşılmadı. Ayrı bir yönetici inceleme hesabı gerekirse Google'ın bildirimine göre değerlendirilmelidir.

## İşletmede takip edilecekler

- Gizlilik politikasındaki 1 yıllık saklama süresinin takibi uygulama sorumlusuna aittir; otomatik yıllık veri temizleme zamanlayıcısı yoktur. Silme talepleri panelden ve yayımlanan iletişim adresinden takip edilmelidir.
- `native-ios/` içindeki ayrı eski Swift istemci bu Android yayınının kapsamı değildir; yeni güvenlik modeline geçirilmeden ayrıca yayımlanmamalıdır.
- Önceden açık veritabanının geçmişte üçüncü kişilerce okunup okunmadığı bu çalışma ile belirlenmiş değildir.

## Politika kaynakları

- [Google Play kullanıcı verileri](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Sağlık içeriği](https://support.google.com/googleplay/android-developer/answer/16679511)
- [AI içerik ve uygulama içi bildirme](https://support.google.com/googleplay/android-developer/answer/13985936)
- [Veri güvenliği](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Firebase SDK veri açıklamaları](https://firebase.google.com/docs/android/play-data-disclosure)
- [Firebase gizlilik](https://firebase.google.com/support/privacy/)

Güncel politika: https://sites.google.com/view/rehberlik-gizlilik-politikasi/ana-sayfa
