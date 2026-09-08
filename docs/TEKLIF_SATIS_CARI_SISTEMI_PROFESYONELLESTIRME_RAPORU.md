# Teklif, Satış Takibi ve Cari Yönetimi Profesyonelleştirme Raporu

**İncelenen uygulama:** `uzalteklif`  
**Rapor tarihi:** 6 Eylül 2026  
**Kapsam:** Teklif hazırlama, fiyatlandırma, şirket içi onay, müşteri gönderimi, görüntülenme/yanıt takibi, satış fırsatı yönetimi, cari kartları, teklif PDF'i, veri modeli, yetkilendirme ve test altyapısı.

---

## 1. Yönetici özeti

Uygulama bugün ürün kataloğundan teklif oluşturabilen, döviz kuru anlık görüntüsü saklayan, PDF/Excel üreten, teklif kopyalama ve revizyon yapabilen işlevsel bir araçtır. Sorun özellik sayısının az olması değildir. Asıl sorun, ürünün üç farklı kimlik arasında kalmasıdır:

1. Ürün/fiyat kataloğu,
2. Teklif PDF'i hazırlama aracı,
3. Satış ve cari takip sistemi.

Bu üç alan aynı ekranlarda birbirine karıştığı için satış personeli açısından sistem hızlı ve yönlendirici bir çalışma masası gibi değil, çok sayıda alanı doldurması gereken teknik bir form gibi hissedebilir. Yönetim açısından ise gerçek satış faaliyetini ölçen güvenilir bir CRM değildir; gönderildi, görüntülendi, cevaplandı, kazanıldı gibi bilgiler çoğunlukla tek alanla veya manuel kullanıcı işlemiyle temsil edilmektedir.

En önemli sonuç şudur:

> Uygulama yalnız görsel olarak yenilenmemeli; "teklif belgesi" merkezli yapıdan "satış fırsatı ve aktivite" merkezli yapıya geçirilmelidir.

### Genel olgunluk değerlendirmesi

| Alan | Mevcut seviye | Ana sorun |
|---|---:|---|
| Ürün kataloğu ve fiyat seçimi | 7/10 | Müşteri fiyatı, maliyet ve marj politikası eksik |
| Teklif hazırlama hızı | 5/10 | Editör fazla yoğun, otomatik kayıt ve hızlı veri girişi yok |
| Ticari onay | 5/10 | Durum adları ve geçiş yetkileri güvenilir değil |
| E-posta/WhatsApp gönderimi | 3/10 | İstemcinin açılması gönderim olarak kaydediliyor |
| Görüntülenme takibi | 2/10 | Alan var; çalışan public portal ve olay kaydı görünmüyor |
| Müşteri kabulü | 2/10 | Satıcı tarafından işaretlenebilir; müşteri kanıtı yok |
| Satış fırsatı ve takip | 3/10 | Aktivite, görev, sonraki aksiyon ve tahmin modeli yok |
| Cari/CRM | 4/10 | Cari 360 görünümü var fakat veri modeli adres defteri seviyesinde |
| Finansal cari takip | 1/10 | Bakiye, borç/alacak, fatura, tahsilat ve risk limiti yok |
| Teklif PDF'i | 7/10 | Temel çıktı güçlü; sürüm, kabul ve dijital doğrulama geliştirilmeli |
| Raporlama | 4/10 | Basit sayılar var; dönüşüm, süre, neden ve tahmin analizi yok |
| Veri güvenliği ve izlenebilirlik | 5/10 | Audit altyapısı var; işlem yetkileri ve public paylaşım eksik |

---

## 2. Satış ekibi programı neden sevmiyor olabilir?

Bu bölüm kullanıcı görüşmesi yapılmadan, mevcut ekran ve kod yapısından çıkarılmış olası nedenleri gösterir. Gerçek nedenleri doğrulamak için 5-8 satış kullanıcısıyla görev bazlı kullanılabilirlik testi yapılmalıdır.

### 2.1 Teklif editörü tek ekranda gereğinden fazla sorumluluk taşıyor

`lib/screens/quote_editor_page.dart` yaklaşık 5.500 satırdır. Aynı ekran şunların tamamını yönetmektedir:

- Cari ve müşteri yetkilisi,
- Teklifi hazırlayan personel,
- Teklif konusu ve notları,
- Ürün kataloğu,
- Kategori/grup düzeni,
- Miktar, birim fiyat ve iskonto,
- Gizli maliyet/yükleme,
- Para birimi ve kur dönüşümü,
- Ödeme yöntemi ve vade,
- Teslim ve geçerlilik koşulları,
- PDF, Excel ve malzeme istek çıktıları,
- Taslak kaydı ve onaya gönderim.

Bu yapı deneyimli kullanıcıya kontrol sağlasa da, sık teklif hazırlayan satışçı için bilişsel yük oluşturur. Kullanıcı her teklif için hangi alanın gerekli, hangisinin ileri seviye olduğunu ayırt etmek zorunda kalır.

**Öneri:** Editörü üç aşamalı, kaybolmayan bir çalışma akışına bölün:

1. **Müşteri ve fırsat:** Cari, yetkili, teklif konusu, son tarih.
2. **Kalemler ve fiyat:** Ürünler, miktar, iskonto, alternatifler, toplam ve marj.
3. **Koşullar ve gönderim:** Ödeme, teslim, geçerlilik, ön izleme, onay/gönderim.

İleri alanlar "Ticari detaylar" altında açılır olmalıdır. Ürün ekleme ve toplam ise her zaman görünür kalmalıdır.

### 2.2 Satışçı için en sık yapılan işlem yeterince kısa değil

Profesyonel bir teklif aracında standart teklif şu akışla 1-2 dakika içinde hazırlanabilmelidir:

`Cari seç -> yetkili seç -> hazır paket/önceki teklif seç -> miktarları düzelt -> ön izle -> gönder`

Mevcut sistem teklif kopyalayabiliyor; ancak gerçek bir şablon, favori ürün, paket, müşteri fiyat listesi veya son kullanılan kalemler kütüphanesi yoktur. Kopyalama eski fiyatları ve eski teklif bağlamını taşıma riski yaratır.

**Öneri:**

- "Son kullandıklarım", "Favorilerim" ve "Bu cariye daha önce satılanlar" sekmeleri,
- Tek tıkla eklenen ürün/hizmet paketleri,
- Teklif şablonları: pano otomasyonu, servis sözleşmesi, devreye alma, bakım vb.,
- Satırları Excel'den yapıştırma,
- Barkod/ürün kodu ile hızlı ekleme,
- Klavye ile tamamen kullanılabilen satır editörü,
- Satır çoğaltma ve çoklu satır güncelleme,
- "Yeni teklifte güncel fiyatları kullan / eski fiyatları koru" seçimi.

### 2.3 Otomatik taslak ve kurtarma mekanizması görünmüyor

Kayıt, kullanıcının "Taslak Olarak Kaydet" veya "Teklifi Tamamla" işlemiyle yapılıyor. Uzun teklif hazırlanırken pencerenin kapanması, oturumun düşmesi veya bağlantı sorunu veri kaybı korkusu yaratır.

**Öneri:**

- Her 10-15 saniyede değişiklik bazlı otomatik taslak,
- Sağ üstte "Kaydedildi / Kaydediliyor / Çevrimdışı" göstergesi,
- Yerel geçici kurtarma kopyası,
- Ekrandan çıkarken kaydedilmemiş değişiklik uyarısı,
- Çakışma halinde iki sürümü yan yana birleştirme ekranı.

Mevcut `updated_at` kontrolü aynı teklifin eş zamanlı güncellenmesini yakalamak için iyi bir başlangıçtır; kullanıcıya yalnız hata göstermek yerine birleştirme deneyimi eklenmelidir.

### 2.4 Terminoloji satış sürecini anlaşılmaz hale getiriyor

`QuoteStatus` içinde saklama anahtarı ve kullanıcı etiketi farklı anlamlar taşımaktadır:

- `pending` modeli veritabanında `sent` olarak saklanıyor fakat arayüzde "Gönderime Hazır",
- `approved` arayüzde "Müşteriye Gönderildi",
- Müşteri yanıtı ayrı bir `customer_response` alanında,
- E-posta gönderimi ayrıca `email_sent_at` alanında.

Bu nedenle bir teklifin gerçek durumu üç farklı alandan yorumlanmaktadır. Örneğin `approved` olan teklif e-posta ile hiç gönderilmemiş olabilir.

**Önerilen tek ve anlaşılır teklif yaşam döngüsü:**

`draft -> approval_pending -> approved -> sent -> viewed -> negotiating -> won/lost/expired/cancelled`

Burada:

- `approved`, yalnız şirket içi ticari onayı ifade eder.
- `sent`, sistemin gerçekten gönderim sağlayıcısından başarı aldığı anlamına gelir.
- `viewed`, müşteri portalında doğrulanmış ilk açılıştır.
- `won`, müşteri kabul kanıtı veya yetkili yönetici kaydıyla oluşur.
- `lost` için yapılandırılmış kayıp nedeni zorunludur.

Durum değişiklikleri serbest sürükle-bırak yerine sunucu tarafında geçiş kurallarıyla korunmalıdır.

---

## 3. Mevcut sistemin güçlü tarafları

Yeniden yazmak yerine korunup geliştirilebilecek önemli parçalar vardır:

- Ürün kataloğu, kategori, marka/model ve gelişmiş arama,
- CSV ürün aktarımı,
- Döviz kurlarının teklif üzerinde anlık görüntü olarak saklanması,
- TL, USD ve EUR teklif hazırlama,
- Teklif kalemlerini kategorilere ayırma ve kategori ara toplamları,
- Satır ve toplu iskonto,
- PDF'te görünmeyen ek maliyetlerin görünür fiyatlara dağıtılması,
- Çoklu cari yetkilisi,
- Cari üzerinden teklif oluşturma ve teklif geçmişini görüntüleme,
- Teklif kopyalama,
- Revizyon sayacı ve veritabanı revizyon anlık görüntüsü,
- Audit log altyapısı,
- İyimser eş zamanlılık kontrolü (`updated_at`),
- PDF ve Excel çıktıları,
- Çok sayfalı PDF, sabit başlık/alt bilgi ve sayfa numarası,
- Windows Outlook taslağına PDF ekleme,
- WhatsApp mesaj taslağı,
- Kişisel çalışma masasında cevapsız teklif uyarısı,
- Yönetici ve satış rolleri için başlangıç düzeyinde yetkilendirme.

Bu parçalar değerlidir; önerilen dönüşüm bunları kaldırmayı değil, güvenilir bir satış sürecine bağlamayı amaçlamaktadır.

---

## 4. Kritik hatalar ve güven problemleri

## P0 - Profesyonel gönderim ve takipten önce düzeltilmesi gerekenler

### P0.1 E-posta taslağının açılması "gönderildi" olarak kaydediliyor

`cari_detail_page.dart` içinde Outlook taslağı başarıyla açıldıktan hemen sonra `markEmailSent` çağrılıyor. Aynı davranış `mailto:` istemcisi açıldığında da vardır. Kullanıcı taslağı kapatabilir, alıcıyı silebilir veya gönderim başarısız olabilir; sistem yine de teklifi gönderilmiş sayar.

Bu hata şu metrikleri güvenilmez yapar:

- Gönderilen teklif sayısı,
- Cevap bekleme süresi,
- Üç günlük gecikme uyarısı,
- Gönderim yapılan alıcı,
- Satışçı performansı.

**Doğru çözüm:** E-posta bir sunucu sağlayıcısı üzerinden gönderilmeli ve sağlayıcının teslim olayları kaydedilmelidir. En az şu olaylar bulunmalıdır:

`queued`, `sent`, `delivered`, `bounced`, `opened`, `clicked`, `failed`

Outlook kullanılmaya devam edilecekse kayıt adı "E-posta taslağı açıldı" olmalı; kullanıcı sonradan "Gönderildi olarak işaretle" diyebilmelidir. Bu yine de kesin teslim kanıtı değildir.

### P0.2 Görüntülenme alanı var ancak çalışan müşteri portalı görünmüyor

Kodda `email_viewed_at`, `public_token`, QR/public link üretimi ve `#/p/{token}` benzeri URL'ler vardır. Buna karşılık `uzalteklif` içinde anonim müşteriye teklif gösteren route, public teklif endpoint'i veya görüntülenmeyi güvenli şekilde işleyen uygulama kodu bulunmamaktadır.

Sonuç olarak arayüz profesyonel takip varmış izlenimi verirken uçtan uca özellik tamamlanmamış olabilir.

**Öneri:** Ayrı bir müşteri teklif portalı oluşturun:

- Token ile yalnız yayımlanmış teklif sürümünü getirir,
- İlk açılış ve sonraki açılışları ayrı olaylar olarak kaydeder,
- PDF indirildi olayını kaydeder,
- Sorular ve revizyon talebi alınabilir,
- Kabul/ret işlemi kimlik doğrulama ve açık rıza ile yapılır,
- Teklif geri çekildiğinde veya süresi dolduğunda bunu açıkça gösterir.

### P0.3 Dört karakterli public token ve benzersiz olmayan indeks yetersizdir

`QuoteCodeGenerator.shareTokenLength` değeri 4'tür. Kod yorumuna göre yaklaşık 923 bin kombinasyon vardır. `quotes_public_token_idx` yalnız normal bir indekstir; benzersizlik garantisi vermez.

Public teklif erişimi için bu değer sır olarak kabul edilemez. Token tahmini, çakışma ve başka müşterinin belgesine erişim riski doğurur.

**Öneri:**

- En az 128 bit rastgele token,
- Veritabanında yalnız token hash'i,
- `unique` indeks,
- Süre sonu ve iptal tarihi,
- Kullanım amacı/sürüm kapsamı,
- Rate limit ve erişim olayı,
- Token yenileme ve eski bağlantıyı iptal etme.

### P0.4 Müşteri cevabı gerçek müşteri cevabı değil

`customer_response`, uygulama içindeki yetkili kullanıcı tarafından doğrudan güncellenebiliyor. Bunun müşteri tarafından verildiğini kanıtlayan kişi, IP, kullanıcı ajanı, doğrulama yöntemi, kabul metni sürümü veya zaman damgalı delil kaydı yoktur.

Bu alan "satış personelinin beyan ettiği müşteri sonucu" olarak adlandırılmalı veya gerçek dijital kabul akışı kurulmalıdır.

**Profesyonel kabul kaydı şunları içermelidir:**

- Kabul edilen teklif sürümü ve PDF hash'i,
- Müşteri cari ve yetkili kimliği,
- Doğrulanan e-posta/telefon,
- Kabul/ret zamanı,
- IP ve kullanıcı ajanı,
- Kabul edilen toplam, para birimi, KDV ve koşullar,
- Açık kabul metni,
- Kabul kanıtı belgesi,
- İş emri oluşturma sonucu.

### P0.5 Durum geçişleri ve yetkiler sunucu tarafında korunmuyor

Teklif listesinde Kanban sürükle-bırak ile hedef duruma doğrudan geçilebiliyor. Teklif detayında da durum menüsü bulunmaktadır. RLS kaydı güncelleme yetkisini kontrol etse de hangi alanın veya hangi durum geçişinin değişebileceğini kontrol etmemektedir.

Böylece düzenleme yetkisi olan bir kullanıcı:

- Onay beklemeden müşteriye gönderildi durumuna,
- Müşteri kanıtı olmadan kazanıldı durumuna,
- Gerekçe olmadan kaybedildi/iptal durumuna

geçebilir.

**Öneri:** Bütün durum değişiklikleri tek bir PostgreSQL RPC veya Edge Function üzerinden yapılmalı; rol, mevcut durum, hedef durum ve zorunlu alanlar sunucuda doğrulanmalıdır.

### P0.6 Onaylanan/gönderilen müşteri belgesi sürüme sabitlenmemiştir

Veritabanında `quote_revisions` anlık görüntüleri vardır; fakat gönderim kaydı belirli bir revision/PDF nesnesine bağlanmamıştır. Aynı teklif daha sonra değiştiğinde müşterinin hangi içeriği gördüğü veya hangi PDF'i aldığı kesin olarak çıkarılamaz.

**Öneri:** Her yayımlama işleminde değişmez bir `quote_version` oluşturun:

- `quote_id`, `version_no`,
- Tam ticari JSON snapshot,
- Üretilen PDF storage yolu,
- SHA-256 hash,
- Oluşturan/onaylayan,
- Yayımlanma ve geri çekilme zamanı.

E-posta, portal görüntüleme, kabul ve iş emri bu sürüm kimliğine bağlanmalıdır.

### P0.7 Fiyatlandırmada maliyet ve marj görünürlüğü yok

`HiddenCostItem` ile PDF'te görünmeyen yüklemeler fiyata dağıtılabiliyor. Ancak sistemde satır bazlı alış maliyeti, standart maliyet, hedef marj, gerçekleşen brüt kâr ve indirim sonrası marj kapısı görünmüyor.

"Gizli yükleme" yaklaşımı tek başına profesyonel fiyatlandırma değildir. Maliyetle satış fiyatını karıştırabilir ve neden-sonuç analizini zorlaştırır.

**Öneri:** Her kalemde ayrı alanlar kullanın:

- Standart/son alış maliyeti,
- Kur ve maliyet tarihi,
- Lojistik/işçilik/genel gider payı,
- Liste satış fiyatı,
- İskonto,
- Net satış fiyatı,
- Marj tutarı ve marj yüzdesi.

Satışçı müşteriye yalnız satış fiyatını görür; iç özet panelinde marjı görür. Belirlenen eşik altındaki marj veya yüksek iskonto otomatik yönetici onayı gerektirir.

### P0.8 Teklif kabulü operasyonel süreci başlatmıyor

Teklifin `accepted/won` olması, kök uygulamada tekil ve izlenebilir iş emri oluşturmuyor. Bu konu önceki uçtan uca raporda da kritik bulgu olarak yer almaktadır.

**Öneri:** Kazanım işlemi atomik olmalıdır:

1. Müşteri kabul kanıtı kaydedilir.
2. Teklif sürümü kilitlenir.
3. Tek iş emri oluşturulur.
4. Kaynak teklif ve kapsam kalemleri bağlanır.
5. Satışçı ve operasyon ekibi bilgilendirilir.

---

## 5. Teklif hazırlama deneyimi nasıl profesyonelleştirilmeli?

## P1 - Satış verimliliği

### 5.1 Yeni teklif açılış ekranı

Tek bir "Yeni Teklif" butonu sonrasında kullanıcıya dört başlangıç yolu verin:

- Boş teklif,
- Hazır şablondan,
- Önceki tekliften,
- Keşif/projeden.

Her seçenekte neyin taşınacağı açık olmalıdır. Özellikle önceki tekliften kopyalamada:

- Güncel ürün fiyatları mı, eski fiyatlar mı?
- Güncel kur mu, eski kur mu?
- Müşteri ve yetkili taşınsın mı?
- Ticari koşullar taşınsın mı?

soruları tek bir küçük diyalogda seçilmelidir.

### 5.2 Minimal ve gelişmiş mod

Standart satışçıya yalnız gerekli alanları gösterin:

- Cari,
- Yetkili,
- Konu,
- Teklif kalemleri,
- Toplam,
- Ödeme/teslim/geçerlilik,
- Ön izleme ve gönder.

Maliyet dağıtımı, şirket profili, teknik gruplama, fiyat gizleme ve malzeme istek çıktıları "Gelişmiş" modda yer almalıdır. Malzeme istek PDF'i satış teklif editörünün ana aksiyonları arasında olmamalı; operasyon modülüne taşınmalıdır.

### 5.3 Kalem tablosu Excel kadar hızlı olmalı

Önerilen davranışlar:

- Enter ile sonraki hücre/satır,
- Ürün kodu yazarken anlık eşleşme,
- Çoklu ürün seçimi,
- Excel'den satır yapıştırma,
- Satır sürükleyerek sıralama,
- Çoklu seçimle iskonto/kategori/silme,
- Klavye kısayolları,
- Geri al/yinele,
- Birim ve para birimi doğrulaması,
- Satır bazında opsiyonel/alternatif ürün,
- Ürün stok ve termin uyarısı,
- Muadil ürün önerisi.

### 5.4 Hazır paket ve konfigürasyon sistemi

Teklif şablonu yalnız şirket/banka varsayılanlarından ibaret olmamalıdır. Aşağıdaki yapı oluşturulmalıdır:

- **Belge şablonu:** Logo, kapak, koşullar, standart metinler.
- **Ticari şablon:** Ödeme, teslim, geçerlilik, para birimi.
- **Ürün paketi:** Birlikte satılan ürün/hizmet kalemleri ve varsayılan miktarlar.
- **Konfigürasyon kuralı:** Seçime göre zorunlu/uyumsuz/muadil ürünler.
- **Müşteri şablonu:** Cari özel iskonto, fiyat listesi ve koşullar.

### 5.5 Fiyat ve kur güvenliği

Mevcut kur snapshot yaklaşımı korunmalı, ancak şu bilgiler görünür olmalıdır:

- Kur sağlayıcısı,
- Kurun alındığı tarih/saat,
- Uygulanan alış/satış kuru veya özel kur,
- Kur geçerlilik tarihi,
- Kur değişirse teklif yenileme uyarısı,
- Müşteriye sunulan para biriminde yuvarlama politikası.

Kopyalanan teklif eski snapshot ile açıldığı için kullanıcıya "Bu teklif eski kur/fiyat içeriyor" uyarısı gösterilmeli ve tek tıkla güncelleme sunulmalıdır.

### 5.6 İskonto ve onay matrisi

Mevcut indirim doğrulaması teknik olarak `-100` ile `100` arasını kabul etmektedir. Negatif iskonto fiilen fiyat artışı anlamına gelir ve kullanıcı açısından belirsizdir.

**Öneri:**

- İskonto yalnız `0-100` aralığında olsun.
- Fiyat artışı ayrı "fiyat çarpanı/yükleme" alanı olsun.
- Satıcı bazlı maksimum iskonto,
- Ürün grubu bazlı minimum marj,
- Teklif toplamı ve risk seviyesine göre onay zinciri,
- Onay talebinde değişen satırların özeti,
- Onay sonrası ticari alan kilidi.

### 5.7 Geçerlilik serbest metin değil tarih olmalı

`validityText` bugün serbest metindir. "15 gün" yazısı raporlama ve otomatik süre dolumu için kullanılamaz.

**Öneri:** `valid_until` zorunlu tarih alanı olsun. PDF'te hem tarih hem süre gösterilsin. Süresi dolan teklif otomatik `expired` olsun; satışçıya yenileme aksiyonu çıksın.

### 5.8 Teklif numarası veritabanından üretilmeli

Teklif kodu istemci saatinin saniye çözünürlüğünden oluşturuluyor ve veritabanında `unique`. İki kullanıcının aynı saniyede teklif oluşturması çakışabilir.

**Öneri:** Teklif numarası veritabanı fonksiyonu/sequence ile üretilsin. Örnek:

`TKL-2026-000184-R02`

Public erişim tokeni teklif numarasından tamamen bağımsız olmalıdır.

---

## 6. Profesyonel gönderme ve müşteri iletişimi

### 6.1 Gönderim merkezi

Teklif detayında tek bir "Gönder" akışı olmalıdır:

1. Alıcı ve CC seçimi,
2. E-posta şablonu,
3. Gönderilecek teklif sürümü,
4. PDF ekle / portal linki ekle seçenekleri,
5. Ön izleme,
6. Sunucu üzerinden gönderim,
7. Teslim ve etkileşim takibi.

Her gönderim ayrı kayıt olmalıdır; tek `email_sent_at/email_sent_to` alanı geçmişi temsil edemez.

Önerilen `quote_deliveries` alanları:

| Alan | Amaç |
|---|---|
| `id` | Gönderim kimliği |
| `quote_version_id` | Gönderilen sabit sürüm |
| `channel` | email, whatsapp, portal, manual |
| `recipient_contact_id` | Cari yetkilisi |
| `to/cc` | Gönderim adresleri |
| `provider_message_id` | Sağlayıcı doğrulaması |
| `status` | queued/sent/delivered/bounced/failed |
| `sent_at/delivered_at` | Zamanlar |
| `sent_by` | İşlemi yapan |
| `subject/body_snapshot` | Gönderilen içerik |

### 6.2 Olay bazlı etkileşim takibi

Tek bir `email_viewed_at` yerine `quote_events` tablosu kullanılmalıdır:

- `email_sent`,
- `email_delivered`,
- `email_opened`,
- `link_clicked`,
- `portal_viewed`,
- `pdf_downloaded`,
- `question_submitted`,
- `revision_requested`,
- `accepted`,
- `rejected`.

Bot ve güvenlik tarayıcılarının e-posta linklerini otomatik açabileceği unutulmamalıdır. "E-posta açıldı" ile "müşteri teklifi inceledi" ayrı tutulmalıdır.

### 6.3 WhatsApp gönderimi

Mevcut uygulama WhatsApp mesaj taslağı açmaktadır. Bu yararlı bir kısayoldur fakat teslim kanıtı değildir.

Profesyonel seçenekler:

- Basit aşama: "WhatsApp açıldı" aktivitesi ve kullanıcı tarafından gönderildi teyidi,
- Kurumsal aşama: WhatsApp Business API ile şablon mesaj ve teslim olayları,
- Her iki durumda da gönderilen teklif sürümü ve alıcı kişi kaydedilmelidir.

### 6.4 Takip otomasyonu

Sabit "3 gün geçti" kuralı yerine firma tarafından ayarlanabilir takip planları oluşturulmalıdır:

- Gönderildi, 1 iş günü açılmadı -> satışçıya hatırlat,
- Görüntülendi, 2 iş günü cevap yok -> arama görevi,
- Geçerliliğe 3 gün kaldı -> yenileme/hatırlatma,
- Süre doldu -> expired ve yeniden teklif önerisi,
- Müşteri revizyon istedi -> sorumlu ve son tarih ata.

Otomasyon müşteriye kontrolsüz mesaj göndermemeli; ilk aşamada personele görev üretmelidir.

---

## 7. Satış fırsatı ve pipeline sistemi

Teklif, satış fırsatının yalnız bir çıktısıdır. Aynı fırsatta birden fazla teklif sürümü veya alternatif teklif bulunabilir. Bu nedenle `opportunities` tablosu eklenmelidir.

### Önerilen fırsat alanları

- Fırsat adı,
- Cari ve ilgili yetkililer,
- Satış sorumlusu ve ekip,
- Kaynak/kanal,
- Ürün/hizmet ailesi,
- Tahmini tutar ve para birimi,
- Kazanma olasılığı,
- Beklenen kapanış tarihi,
- Pipeline aşaması,
- Sonraki aksiyon ve tarihi,
- Rakip,
- Kayıp nedeni,
- Bağlı keşif, teklifler ve iş emri.

### Önerilen pipeline

`lead -> qualified -> discovery -> solution -> proposal -> negotiation -> won/lost`

Teklif durumuyla fırsat aşaması aynı şey değildir. Örneğin müşteri yeni revizyon isterse teklif sürümü kapanabilir fakat fırsat hâlâ `negotiation` aşamasında kalır.

### Satışçının ana ekranı

Kişisel çalışma masası şu sorulara anında cevap vermelidir:

- Bugün kimi aramalıyım?
- Hangi teklifler onay bekliyor?
- Hangi müşteriler teklifi görüntüledi ama cevap vermedi?
- Bu hafta süresi dolacak teklifler hangileri?
- Hangi fırsatlarda sonraki aksiyon yok?
- Aylık hedefime ne kadar kaldı?
- Kazanma ihtimali yüksek toplam pipeline nedir?

Ana ekran ürün listesinden çok bu aksiyonları öne çıkarmalıdır. Ürün kataloğu ayrı bir çalışma alanı olarak kalabilir.

### Yönetici ekranı

Yönetici için şu metrikler gereklidir:

- Teklif adedi ve tutarı,
- Onay bekleme süresi,
- Teklif hazırlama süresi,
- Gönderimden ilk görüntülemeye süre,
- Gönderimden sonuçlanmaya süre,
- Kazanma oranı: adet ve tutar bazlı,
- Satışçı, ürün grubu, müşteri segmenti ve kaynak bazında dönüşüm,
- Ortalama iskonto ve brüt marj,
- Kayıp nedenleri ve rakip analizi,
- Yaşlandırılmış pipeline,
- Ağırlıklı satış tahmini,
- Hedef/gerçekleşen karşılaştırması.

Bu metrikler anlık `quotes` kayıtlarından değil, sürüm ve olay kayıtlarından üretilmelidir.

---

## 8. Cari sistemindeki eksikler

### 8.1 Mevcut cari aslında gelişmiş bir adres kartıdır

`CariAccount` şu temel alanları içeriyor:

- Firma adı,
- Ana yetkili ve JSON içindeki ek yetkililer,
- Telefon/e-posta,
- Vergi bilgileri,
- Adres,
- Not.

Bu, teklif hazırlamak için yeterli bir müşteri kartı olabilir; ancak profesyonel CRM veya finansal cari takip değildir.

### 8.2 CRM cari ile muhasebe carisi ayrılmalıdır

Kullanıcının "cari takip" beklentisi iki farklı anlama gelebilir:

1. **Satış/CRM carisi:** Firma, yetkili, görüşmeler, fırsatlar, teklifler, görevler.
2. **Finansal cari:** Borç/alacak, fatura, irsaliye, tahsilat, vade, risk limiti, mutabakat.

Bu iki alan tek tabloya doldurulmamalıdır. Finansal kayıtlar mevcut muhasebe/ERP sisteminden entegrasyonla alınmalı; teklif uygulaması finansal bakiyenin özetini göstermelidir. Eğer ayrı ERP yoksa çift taraflı muhasebe mantığını bu teklif uygulamasına gelişigüzel eklemek yerine ayrı bir finans modülü tasarlanmalıdır.

### 8.3 Cari kartına eklenmesi gereken satış alanları

- Müşteri kodu,
- Resmî unvan ve kısa ad,
- Aktif/potansiyel/pasif durum,
- Segment ve sektör,
- Bölge/şehir/ülke,
- Cari sahibi satışçı,
- Kaynak ve etiketler,
- Varsayılan para birimi,
- Varsayılan fiyat listesi/iskonto grubu,
- Ödeme ve teslim koşulları,
- Risk limiti ve finansal özet referansı,
- Fatura, sevk ve servis adresleri,
- KVKK/iletişim izinleri,
- Son aktivite ve sonraki aksiyon,
- Müşteri sağlık skoru.

### 8.4 Yetkililer ayrı tablo olmalıdır

Yetkililer bugün `contacts jsonb` alanında tutuluyor. Bu yaklaşım küçük kullanımda kolaydır; büyüdüğünde şunları zorlaştırır:

- Kişi bazlı arama,
- Aynı kişinin birden fazla lokasyon/rolü,
- Teklif ve aktivitenin belirli kişiye bağlanması,
- İletişim izni,
- İşten ayrılan kişinin pasife alınması,
- Eş zamanlı kişi güncellemesi,
- Kişi bazlı raporlama.

Önerilen tablolar:

- `accounts`,
- `account_contacts`,
- `account_addresses`,
- `account_tags`,
- `account_assignments`,
- `crm_activities`,
- `crm_tasks`.

### 8.5 Mükerrer cari kontrolü yok

Vergi numarası ve normalize firma adı için benzersiz kural görünmüyor. Aynı firma farklı yazımlarla birden fazla kez açılabilir.

**Öneri:**

- Vergi numarası için koşullu benzersiz indeks,
- Normalize firma adı + telefon/e-posta benzerlik kontrolü,
- Kayıt sırasında olası mükerrer uyarısı,
- Yönetici için cari birleştirme aracı,
- Birleştirmede teklifler, aktiviteler ve kişiler yeni kayda taşınmalı.

### 8.6 Cari silme kalıcıdır

`CariRepository.deleteById` doğrudan `delete` çalıştırmaktadır. Tekliflerin `cari_id` alanında açık bir foreign key görünmediğinden silme, eski tekliflerde kopuk referans bırakabilir.

**Öneri:** Cari silinmemeli, `archived_at` veya `is_active=false` ile pasifleştirilmelidir. Mevcut bağlı kayıtlar gösterilmeli; gerçek silme yalnız veri yöneticisi ve yasal saklama politikası kapsamında yapılmalıdır.

### 8.7 Veri erişimi büyümeye hazır değil

Teklif ve cari repository'leri bütün kayıtları `.select()` ile çekip arama/filtrelemeyi istemcide yapmaktadır. Kayıt sayısı büyüdüğünde açılış süresi, ağ kullanımı ve bellek tüketimi artacaktır.

**Öneri:**

- Sunucu tarafı arama, filtre ve sıralama,
- Sayfalama/cursor,
- Özet sorguları veya materialized view,
- Sık kullanılan alanlara indeks,
- Yetki kapsamına göre veri daraltma,
- İptal edilebilir arama ve debounce.

### 8.8 Cari erişim yetkisi fazla geniş olabilir

Tüm authenticated kullanıcılar carileri okuyabiliyor; geniş bir satış/operasyon/finans rol listesi carileri güncelleyebiliyor. Bu şirket politikasına göre bilinçli olabilir fakat sahiplik, ekip, bölge ve hassas finansal bilgi ayrımı yoktur.

**Öneri:**

- Firma geneli temel kart erişimi,
- Sorumlu ekip bazlı satış notları,
- Finans rolüne özel bakiye/risk alanları,
- Alan bazlı güncelleme yetkisi,
- Hassas veri görüntüleme audit'i.

---

## 9. Teklif PDF'i nasıl daha profesyonel olabilir?

### Mevcut iyi özellikler

- Noto Sans ile Türkçe karakter desteği,
- A4 ve `MultiPage`,
- Her sayfada kurumsal başlık ve alt bilgi,
- `Sayfa X/Y`,
- Teklif kodu,
- Cari ve hazırlayan bilgileri,
- Kategori bazlı kalem tabloları,
- KDV ve toplam,
- Ödeme/teslim/geçerlilik,
- Banka bilgileri,
- Fiyatlı veya fiyatsız çıktı,
- Kabul/mutabakat bölümü,
- Büyük ve uzun içeriklere yönelik testler.

### İyileştirilmesi gerekenler

#### 9.1 Teklif sürümü her sayfada açık olmalı

Teklif numarası yanında `Revizyon 02`, yayımlanma tarihi ve sürüm kimliği gösterilmelidir. Eski sürümlerde büyük ve görünür "GEÇERSİZ SÜRÜM" damgası uygulanabilmelidir.

#### 9.2 Geçerlilik kesin tarih olarak yazılmalı

"15 gün" yerine:

`Teklif geçerlilik tarihi: 21.09.2026`

yazılmalı; kur sabitleme koşulu ayrıca açıklanmalıdır.

#### 9.3 Kapsam ve kapsam dışı işler ayrılmalı

Teknik tekliflerde profesyonel anlaşmazlık önleme için şu bölümler şablonlanmalıdır:

- İşin kapsamı,
- Kapsam dışı işler,
- Müşteri sorumlulukları,
- Teknik kabuller,
- Teslim şekli,
- Garanti,
- Devreye alma ve eğitim,
- Teklif varsayımları.

#### 9.4 Alternatif ve opsiyonel kalem desteği

Her satır toplam fiyata girmek zorunda olmamalıdır. `included`, `optional`, `alternative`, `excluded` türleri eklenmeli; PDF'te opsiyonlar ayrı toplamla sunulmalıdır.

#### 9.5 Yönetici kaşesi müşteri kabulü gibi görünmemeli

İç onay, müşterinin kabulü değildir. PDF üzerinde şu işaretler ayrı tutulmalıdır:

- "Şirket içi ticari onay",
- "Müşteriye yayımlanan sürüm",
- "Müşteri tarafından dijital kabul edildi".

Müşteri kabul edilmemiş bir PDF'te boş imza alanı bulunabilir; ancak sistem içindeki `accepted` bilgisi müşteri kanıtı olmadan resmî kabul gibi sunulmamalıdır.

#### 9.6 Belge doğrulama

PDF'e güvenli portal QR'ı ve kısa görünen URL eklenebilir. Portal şu bilgileri doğrulamalıdır:

- Teklif numarası ve sürümü,
- Geçerlilik,
- Belge hash'i,
- Güncel/geri çekilmiş/eski sürüm durumu,
- Dijital kabul durumu.

#### 9.7 İç ve dış belge ayrımı

En az iki belge profili bulunmalıdır:

- **Müşteri teklifi:** Satış fiyatı, kapsam ve ticari koşullar.
- **İç maliyet özeti:** Maliyet, yükleme, iskonto, marj ve onay geçmişi.

İç maliyet belgesinin yanlışlıkla müşteriye gönderilmesini engelleyen açık renk/filigran ve yetki kontrolü olmalıdır.

### PDF doğrulama notu

Önceki kapsamlı kontrolde teklif PDF testleri tek başına `5/5` geçmişti. Bu incelemede ilgili beş test dosyası birlikte çalıştırıldığında toplam 15 testin 14'ü geçti; `quote_editor_page_test.dart` içindeki "quote editor shows code plate and adds product lines" testi 79. satırda beklenen widget bulunamadığı için `Bad state: No element` hatası verdi. Ortamda Poppler bulunmadığından üretilen PDF'ler PNG'ye dönüştürülerek görsel piksel/layout denetimi yapılamadı.

---

## 10. Önerilen hedef veri modeli

### Temel tablolar

| Tablo | Sorumluluk |
|---|---|
| `accounts` | Firma/cari ana kartı |
| `account_contacts` | Yetkililer |
| `account_addresses` | Fatura, sevk, servis adresleri |
| `opportunities` | Satış fırsatı/pipeline |
| `quotes` | Teklif üst kaydı ve güncel iş durumu |
| `quote_versions` | Değişmez yayımlanan sürümler |
| `quote_version_lines` | Sürümün fiyat ve kapsam kalemleri |
| `quote_approvals` | Onay adımları ve kararları |
| `quote_deliveries` | Kanal ve gönderim sonuçları |
| `quote_events` | Açılma, indirme, tıklama, cevap olayları |
| `quote_acceptances` | Müşteri kabul/ret kanıtı |
| `crm_activities` | Arama, e-posta, toplantı ve not |
| `crm_tasks` | Takip görevi ve hatırlatma |
| `price_lists` | Müşteri/segment fiyat listesi |
| `pricing_rules` | İskonto, marj ve onay kuralları |
| `quote_templates` | Belge ve ticari şablonlar |
| `product_bundles` | Hazır ürün/hizmet paketleri |

### `quotes` tablosunda olması gereken temel alanlar

- `opportunity_id`,
- `account_id`,
- `primary_contact_id`,
- `owner_user_id`,
- `status`,
- `valid_until`,
- `current_version_id`,
- `currency_code`,
- `total_net`, `total_tax`, `total_gross`,
- `cost_total`, `margin_total`, `margin_rate`,
- `expected_close_at`,
- `next_action_at`,
- `won_at/lost_at`,
- `loss_reason_id`,
- `source_quote_id` kopyalama ilişkisi,
- `created_at/updated_at/archived_at`.

Parasal alanlar `double` yerine veritabanında `numeric`, uygulamada hassas decimal yaklaşımıyla işlenmelidir. Para birimi kodları `USDTRY` gibi kur sembolü yerine belge para birimi olarak `USD`, `EUR`, `TRY` tutulmalıdır; kur çifti ayrıca saklanmalıdır.

---

## 11. Önerilen ekran mimarisi

### 11.1 Satışçı çalışma masası

- Bugünkü görevler,
- Geciken takipler,
- Onay bekleyenler,
- Görüntülenip cevaplanmayanlar,
- Süresi dolacak teklifler,
- Son müşteri aktiviteleri,
- Kişisel hedef ve pipeline.

### 11.2 Fırsat detay ekranı

Tek ekranda zaman çizgisi:

`İlk temas -> keşif -> toplantı -> teklif V1 -> e-posta -> görüntüleme -> revizyon V2 -> kabul -> iş emri`

Sağ panelde cari, sorumlu, tutar, olasılık, beklenen kapanış ve sonraki aksiyon bulunmalıdır.

### 11.3 Teklif editörü

- Üstte cari/fırsat ve otomatik kayıt durumu,
- Ortada hızlı kalem tablosu,
- Sağda müşteri toplamı ve iç marj özeti,
- Altta sabit "Taslak", "Ön izleme", "Onaya gönder" aksiyonları,
- Malzeme istek ve operasyon çıktıları ayrı menü/modül.

### 11.4 Teklif detay ekranı

- Güncel sürüm,
- Sürüm karşılaştırma,
- Onay geçmişi,
- Gönderimler,
- Müşteri etkileşimleri,
- Aktiviteler ve görevler,
- Kabul/ret kanıtı,
- Oluşan iş emri.

### 11.5 Cari 360

- Firma özeti,
- Yetkililer ve adresler,
- Aktiviteler,
- Fırsatlar,
- Teklifler,
- Kazanılan işler,
- Servis geçmişi,
- Finansal özet,
- Belgeler,
- Riskler ve sonraki aksiyonlar.

---

## 12. Kullanıcı benimseme planı

Satış ekibinin sistemi beğenmemesi yalnız teknik eksiklerle çözülmez. Uygulama dönüşümü gerçek kullanıcı görevleriyle yürütülmelidir.

### 12.1 Ölçülecek başlangıç metrikleri

- Standart teklif hazırlama süresi,
- Teklif başına tıklama sayısı,
- Hatalı/eksik teklif oranı,
- Excel/Word'e geri dönme oranı,
- Taslak terk oranı,
- Manuel takip listesi kullanan kişi sayısı,
- Gönderim sonrası sisteme sonuç girme oranı.

### 12.2 Kullanıcı araştırması

Her satışçıyla "ne istiyorsun?" görüşmesinden çok görev testi yapılmalıdır:

1. Mevcut bir müşteriye 10 kalemli teklif hazırla.
2. Eski teklifi güncel fiyatla yenile.
3. Yüzde 10 indirimli teklif için onay al.
4. Teklifi müşteriye gönder ve iki gün sonrası takip görevi oluştur.
5. Kaybedilen teklifi gerekçesiyle kapat.

Ekran kaydı, süre, hata, geri dönüş ve dış araca geçişler gözlemlenmelidir.

### 12.3 Pilot yaklaşımı

- 2 satışçı + 1 yönetici pilot ekip,
- Haftalık kısa geri bildirim,
- Önce hızlı teklif ve gerçek gönderim,
- Ardından görev/pipeline,
- Sonra cari 360 ve ileri raporlama,
- Eski yöntemle paralel kullanım en fazla 2-4 hafta.

### 12.4 Başarı kriterleri

- Standart teklif medyan hazırlama süresi 3 dakikanın altında,
- Tekliflerin en az %95'i cari ve yetkiliye bağlı,
- Gönderimlerin %100'ü değişmez teklif sürümüne bağlı,
- "Gönderildi" kayıtlarının %100'ü sağlayıcı veya açık kullanıcı teyitli,
- Açık fırsatların en az %90'ında sonraki aksiyon ve tarih var,
- Kayıp tekliflerin en az %95'inde yapılandırılmış neden var,
- Manuel Excel/Word teklif kullanımında en az %80 azalma,
- Satış ekibi memnuniyetinde ölçülebilir artış.

---

## 13. Uygulama yol haritası

## Faz 0 - Güven ve doğruluk (1-2 hafta)

- E-posta taslağını "gönderildi" saymayı durdurun.
- Public tokeni güvenli ve benzersiz hale getirin.
- Çalışmayan public görüntülenme iddiasını kaldırın veya tamamlayın.
- Durum geçişlerini sunucu tarafına alın.
- Müşteri cevabını "manuel sonuç" olarak doğru etiketleyin.
- Cari ve teklif kalıcı silmeyi pasifleştirmeye çevirin.
- Encoding/mojibake metinlerini temizleyin.
- Kırık teklif editörü widget testini düzeltin.

## Faz 1 - Hızlı teklif deneyimi (2-4 hafta)

- Üç aşamalı sade editör,
- Otomatik taslak ve kurtarma,
- Hızlı kalem tablosu,
- Favoriler/son kullanılanlar,
- Ürün paketleri ve gerçek teklif şablonları,
- Kopyalamada güncel/eski fiyat seçimi,
- Yapılandırılmış geçerlilik tarihi,
- İç marj özeti.

## Faz 2 - Onay ve sürümleme (2-3 hafta)

- Yeni durum modeli,
- `quote_versions`,
- İskonto/marj onay matrisi,
- Sürüm karşılaştırma,
- Değişmez PDF arşivi ve hash,
- Yayımlanan sürümü geri çekme.

## Faz 3 - Gerçek gönderim ve müşteri portalı (3-5 hafta)

- Sunucu e-posta entegrasyonu,
- `quote_deliveries` ve webhook olayları,
- Güvenli müşteri portalı,
- Görüntüleme/indirme/yanıt olayları,
- Dijital kabul/ret,
- Tekliften atomik iş emri.

## Faz 4 - CRM ve cari 360 (4-6 hafta)

- Fırsat/pipeline,
- Aktivite ve görevler,
- Sonraki aksiyon,
- Normalize yetkili/adres tabloları,
- Mükerrer kontrolü ve birleştirme,
- Cari sahipliği, segment ve etiketler,
- Servis/iş geçmişi bağlantısı.

## Faz 5 - Yönetim, tahmin ve entegrasyon (3-5 hafta)

- Satış hedefleri,
- Ağırlıklı forecast,
- Dönüşüm ve kayıp analizi,
- Satış döngüsü süreleri,
- ERP/muhasebe finansal cari özeti,
- Takvim ve görev entegrasyonu,
- E-posta/WhatsApp otomasyon politikaları.

---

## 14. İlk 30 günde yapılabilecek en değerli işler

1. "Gönderildi" yanlış kaydını düzeltin.
2. Satış ekibiyle beş gerçek görev üzerinden kullanılabilirlik testi yapın.
3. Editörü müşteri, kalemler ve gönderim olarak üç aşamaya bölün.
4. Otomatik taslak kaydı ekleyin.
5. `valid_until`, `next_action_at` ve `owner_user_id` alanlarını ekleyin.
6. Kayıp nedenlerini seçimli hale getirin.
7. Teklif sürümünü değişmez snapshot + PDF olarak saklayın.
8. Ürün paketi ve favori kalem özelliğini ekleyin.
9. Maliyet, net satış ve marjı iç özet panelinde gösterin.
10. Public portal tamamlanana kadar bozuk/kanıtsız görüntülenme göstergelerini kaldırın.
11. Cari mükerrer kontrolü ve pasife alma davranışını ekleyin.
12. Satışçı ana ekranını ürün listesinden "bugünkü aksiyonlar" merkezine taşıyın.

---

## 15. Teknik kalite ve test önerileri

### Zorunlu uçtan uca senaryolar

- Taslak otomatik kaydolur ve tarayıcı kapanınca geri gelir.
- İki kullanıcı aynı teklifi düzenlediğinde veri sessizce ezilmez.
- Yetkisiz satışçı onay veya kazanım yapamaz.
- Onaysız teklif gönderilemez.
- E-posta sağlayıcı başarısızsa `sent` oluşmaz.
- Her gönderim doğru teklif sürümüne bağlıdır.
- Eski/geri çekilmiş token teklifi açamaz.
- Portal görüntülemesi tekil olay olarak kaydolur.
- Müşteri kabulü doğru sürüm ve toplamla saklanır.
- Aynı kabul iki iş emri oluşturmaz.
- Kopyalanan teklif için eski/güncel fiyat tercihi doğru uygulanır.
- Kur değişimi eski teklifi sessizce değiştirmez.
- Düşük marj yönetici onayı olmadan ilerleyemez.
- Cari birleştirme bütün teklif ve aktivite bağlarını korur.
- 10 bin cari/50 bin teklif seviyesinde sayfalama çalışır.
- Uzun Türkçe metin ve çok sayfalı PDF taşma yapmaz.

### CI önerisi

- `flutter analyze` hata halinde pipeline'ı durdurmalı,
- Bütün testler çalıştırılmalı,
- Kritik satış senaryoları entegrasyon testi olmalı,
- SQL migration'lar boş veritabanına uygulanarak test edilmeli,
- RLS için rol bazlı otomatik testler yazılmalı,
- PDF golden/görsel regresyon testi eklenmeli,
- Web public portal için erişim ve token güvenlik testi yapılmalı.

---

## 16. Nihai öneri

Uygulamayı tamamen atmak veya yalnız renklerini değiştirmek doğru çözüm değildir. Mevcut ürün kataloğu, kur snapshot'ı, PDF üretimi, revizyon ve cari bağlantısı iyi bir temel sunmaktadır. Ancak satış ekibinin programı gerçekten benimsemesi için öncelik sırası şöyle olmalıdır:

1. **Güvenilirlik:** Sistem gönderilmemiş teklife gönderildi dememeli; müşteri yanıtı kanıtlı olmalı.
2. **Hız:** Teklif hazırlama Excel kadar akıcı, mevcut yöntemden daha kısa olmalı.
3. **Yönlendirme:** Satışçı bugün ne yapacağını sistemden görmeli.
4. **Ticari kontrol:** Maliyet, marj, iskonto ve onay politikaları görünür olmalı.
5. **Müşteri deneyimi:** Güvenli portal, güncel sürüm, kolay kabul/ret ve profesyonel belge.
6. **Tek kayıt zinciri:** Cari -> fırsat -> teklif sürümü -> gönderim -> kabul -> iş emri birbirine bağlı olmalı.

Bu dönüşüm tamamlandığında sistem yalnız teklif PDF'i hazırlayan bir uygulama olmaktan çıkar; satış ekibinin günlük işini hızlandıran, yönetimin güvenebileceği ve operasyonu doğru veriyle başlatan gerçek bir satış operasyon platformuna dönüşür.

