# Günlük ve Güncelleme Notları

## [1.1.0+5] - 2026-03-18

### Mimari, Guvenlik ve Surec Iyilestirmeleri
- Secret yonetimi `dart-define` tabanina tasindi ve yerel calistirma scriptleri eklendi.
- Bildirim akisi, yetki kontrolleri, ticket yasam dongusu ve merkezi loglama yapisi duzenlendi.
- CI ve teknik dokumantasyon altyapisi guclendirildi.

### Arayuz ve PDF Iyilestirmeleri
- Is listesi, biten isler ve is detayi ekranlarinda kullanilabilirlik odakli duzenlemeler yapildi.
- PDF ciktilari daha sade, daha kurumsal ve daha okunabilir hale getirildi.
- Acik/koyu tema, ortak UI bilesenleri ve genel uygulama kabugu modernlestirildi.

## [1.0.2+3] - 2024-12-24

### ✅ PDF Geliştirmeleri & Hata Düzeltmeleri
- **Font Sorunu Çözüldü:** Web platformunda Türkçe karakterlerin "kutucuk" (X) şeklinde çıkması engellendi. Fontlar artık doğrudan uygulama içindeki Asset klasöründen (`NotoSans-Regular.ttf`) yükleniyor.
- **Web Render Hatası Giderildi:** Web tarayıcılarında PDF önizlemesinde oluşan devasa çapraz çizgiler ve bozulmalar, karmaşık widget'ların (ClipRRect vb.) tasarımı sadeleştirilerek tamamen giderildi.
- **Emoji Koruması:** PDF oluşturulurken "Unable to find a font to draw..." hatasına neden olan emojiler, `TextSanitizer` entegrasyonu ile otomatik olarak temizleniyor.

### ✍️ Akıllı İmza Sistemi (Personel Verimliliği)
- **Kalıcı Personel İmzası:** Personelin her seferinde imza atma zorunluluğu kaldırıldı. Artık personel **Profil** sayfası üzerinden bir kez imzasını tanımlıyor.
- **Otomatik Mühürleme:** Müşteri bir iş emrini imzaladığı anda, o işi yapan personelin imzası da sistem tarafından otomatik olarak iş emrine "mühürleniyor".
- **Zorunlu İmza Yönlendirmesi:** Personel profil imzası olmadan PDF oluşturmaya çalışırsa, sistem otomatik olarak kullanıcıyı profil sayfasına yönlendiriyor.

### 🗄️ Veritabanı & Model Güncellemeleri
- **Supabase Entegrasyonu:** `profiles` tablosuna `signature_data` sütunu eklenerek imzaların bulutta güvenli saklanması sağlandı.
- **Kalıcı Kayıt:** `tickets` tablosu güncellenerek, teknisyen imzasının o andaki kopyasının iş emriyle birlikte saklanması sağlandı.

### 🤖 Android Build & APK Optimizasyonu
- **Kotlin Güncellemesi:** Projenin derlenmesini engelleyen Kotlin sürüm uyuşmazlığı hatası giderildi (`1.8.22` -> `2.1.0` yükseltildi).
- **Release APK:** Uygulamanın optimize edilmiş haliyle 70.4 MB boyutunda Release APK'sı başarıyla oluşturuldu.
- **Yol Haritası:** APK boyutunu daha da küçültmek için "Split APK" ve görsel optimizasyonu planlandı.

