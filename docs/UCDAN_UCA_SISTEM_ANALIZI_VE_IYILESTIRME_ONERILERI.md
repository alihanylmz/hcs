# Uçtan Uca Sistem Analizi ve İyileştirme Önerileri

**Proje:** Uzal Teknik Teklif + İş Takip + Atölye + Servis Sistemi  
**İnceleme tarihi:** 6 Eylül 2026  
**İncelenen kapsam:** `uzalteklif/` teklif uygulaması, kök İş Takip uygulaması, Supabase SQL/RLS kaynakları, teklif kabulü, iş emri, atölye imalatı, sevkiyat, servis ön koşul formu, müşteri/teknisyen imzası, kapanış, bildirimler, stok bağlantıları ve PDF üretimleri.

## 1. Yönetici özeti

Proje işlevsiz veya baştan yazılması gereken bir proje değildir. Teklif hazırlama, teklif PDF'i, iş emri, takım/Kanban, atölye reçetesi, servis notları, fotoğraf, imza, stok ve rapor üretimi gibi değerli parçalar vardır. Sorun, bu parçaların henüz **tek bir iş sürecinin güvenilir aşamaları** olarak çalışmamasıdır.

Bugünkü yapı gerçekte şu şekildedir:

```text
Teklif uygulaması                         İş Takip uygulaması
----------------                         -------------------
Teklif -> "Kazanıldı"                    Elle iş emri açma
        (yalnız quotes güncellenir)       -> İstenirse Kanban kartı açma
                                          -> Kart açıklamasına reçete JSON'u yazma
                                          -> Kart durumunu elle değiştirme
                                          -> İş emri durumunu ayrıca elle değiştirme
                                          -> İstenirse servis ön koşul formu gönderme
                                          -> İmzaları ayrıca toplama
                                          -> İş emrini elle tamamlandı/arşiv yapma
```

Yani uygulamada birden fazla durum listesi bulunmasına rağmen bunları yöneten ortak bir süreç motoru yoktur. Teklif kazanıldığında otomatik ve tekil bir iş kaydı doğmaz; atölye kartı ilerlediğinde ana iş emri ilerlemez; sevkiyat bir kayıt değil kart etiketi/durumudur; servis ön koşul formu devreye alma veya nihai müşteri kabul formu değildir; kapanışta zorunlu belge ve kontrol kapıları uygulanmaz.

### Genel değerlendirme

| Alan | Durum | Kısa hüküm |
| --- | --- | --- |
| Teklif hazırlama ve PDF | Orta/iyi | Özellikli ve testli; ancak kabul yetkisi ve kabulden işe aktarım zayıf. |
| Tekliften iş kabulüne geçiş | Kritik eksik | `accepted` yalnızca teklif kaydını değiştiriyor. |
| İş emri modeli | Orta/zayıf | Çok alan var; teklif ve cariyle kalıcı kaynak ilişkisi yok. |
| Süreç motoru | Kritik eksik | UI geçiş listeleri var, sunucu tarafında geçiş/gate doğrulaması yok. |
| Atölye imalatı | Prototip düzeyi | Kanban açıklamasına gömülü JSON; bağımsız üretim emri/veri modeli değil. |
| Stok/malzeme | Kısmi | Gelişmiş stok modülü var; kabul edilen teklif ve üretim reçetesiyle otomatik rezervasyon yok. |
| Sevkiyat | Kritik eksik | Sevkiyat numarası, kalem, miktar, taşıyıcı, teslim kanıtı ve kısmi sevk yok. |
| Devreye alma | Kritik eksik | Cihaz rehberi ve servis notları var; devreye alma oturumu/protokolü yok. |
| Müşteri formu/imza | Riskli | Ön koşul formu var; RLS ve delil bütünlüğü sorunlu, kapanış kabulü değil. |
| Kapanış/arşiv | Zayıf | `done`/`archived` anlamları ve arşiv ekranı çelişkili; zorunlu kapanış paketi yok. |
| PDF belge seti | Kısmi | Teklif ve iş emri PDF'leri var; üretim/sevkiyat/devreye alma/kapanış zinciri eksik. |
| Yetki/RLS | Kritik riskler var | Bazı önemli eylemler yalnız UI ile sınırlı veya RLS fazla geniş. |
| Test/CI | Yetersiz | Teklif tarafı daha iyi; ana uçtan uca süreç için test yok, kök CI yalnız bir widget testi çalıştırıyor. |

## 2. En kritik bulgular

## P0 - Canlıya çıkmadan önce çözülmesi gerekenler

### P0.1 - Teklif kabulü iş emri oluşturmuyor

`QuoteReviewPage._markAccepted()` yalnızca teklifin durumunu ve mutabık kalınan tutarı kaydediyor. İş emri, müşteri/cari bağlantısı, üretim kapsamı, teslimat kapsamı veya kabul edilen teklif revizyonunun sabit kopyası oluşturulmuyor (`uzalteklif/lib/screens/quote_review_page.dart:105-133`).

Global aramada `tickets` üzerinde `quote_id` / `source_quote_id` ilişkisi bulunmadı. `quote_id` yalnız teklifin normalize kalem tablosunda kullanılıyor. Sonuç olarak:

- Aynı kabul edilen teklif için sıfır, bir veya birden fazla iş emri elle açılabilir.
- İş emrinin hangi teklif revizyonundan doğduğu kanıtlanamaz.
- Teklif sonradan değişirse üretilecek işin özgün ticari kapsamı korunmaz.
- Teklif kalemleri atölye, stok, sevkiyat ve devreye alma kapsamına ayrılamaz.
- Kazanılan tutar ile tamamlanan/faturalanan iş arasında güvenilir rapor kurulamaz.

**Öneri:** Kabul işlemi doğrudan tablo `update` olmamalı. Tek bir sunucu RPC/Edge Function içinde atomik olarak şunları yapmalı:

1. Kullanıcı kabul yetkisini doğrula.
2. Geçerli teklif durumunun `sent/approved` olduğunu doğrula.
3. Kabul edilen revizyon snapshot'ını ve SHA-256 özetini oluştur.
4. Teklifi `accepted` yap.
5. `tickets.source_quote_id` benzersiz ilişkisiyle tek iş emri oluştur veya var olanı döndür.
6. Teklif kalemlerini `job_scope_items` tablosuna kopyala.
7. İşin gerekli aşamalarını (`requires_workshop`, `requires_shipment`, `requires_commissioning`) üret.
8. Audit event ve bildirim/outbox kaydı oluştur.

Bu işlem idempotent olmalıdır: aynı kabul isteği tekrar gelirse ikinci iş emri oluşturmamalıdır.

### P0.2 - Durum makinesi yalnız UI'da; servis ve veritabanı geçişi doğrulamıyor

`TicketStatus.allowedTransitions` doğru yönde atılmış bir adımdır (`lib/models/ticket_status.dart:97-115`). Detay ekranı gösterilecek seçenekleri buradan üretir. Fakat `_changeStatus()` doğrudan genel `updateTicket({'status': status})` çağırır (`lib/pages/ticket_detail_page.dart:1229-1304`). `TicketService.updateTicket()` geçişin izinli olup olmadığını doğrulamadan repository üzerinden update yapar (`lib/services/ticket_service.dart:75-127`). Veritabanında da geçişleri ve kapanış ön koşullarını zorlayan bir RPC/trigger görünmüyor.

Bu nedenle yetkili bir istemci, eski uygulama sürümü veya başka bir ekran:

- `open -> archived`,
- `draft -> done`,
- imzasız ve belgesiz `done`,
- atölye bitmeden `panel_done_sent`

gibi geçişleri yapabilir. Kodda `TicketStatus.canTransition()` tanımlı, fakat hiçbir çağrısı yoktur.

**Öneri:** Bütün durum değişiklikleri `transition_ticket(ticket_id, expected_version, target_status, reason, evidence_ids)` RPC'sinden geçmelidir. RPC rolü, mevcut durumu, hedefi, optimistic lock sürümünü ve aşama kapılarını doğrulamalıdır. Genel `updateTicket` durum alanını kabul etmemeli veya DB trigger doğrudan status update'ini reddetmelidir.

### P0.3 - Teklif durumları yetkisiz/yanlış sırada değiştirilebilir

Teklif detayındaki durum menüsü yönetici kontrolünden bağımsız olarak tüm durumları sunuyor (`uzalteklif/lib/screens/quote_review_page.dart:1163-1204`). Kanban görünümü de her kartı her kolona sürüklemeye izin veriyor (`uzalteklif/lib/screens/quotes_page.dart:625-680`, `744-747`, `865-873`). Yalnız alttaki onay aksiyon çubuğu `isManager` ile korunmuş; alternatif durum menüsü ve sürükle-bırak aynı korumayı kullanmıyor.

RLS, kaydı düzenleme yetkisi olan oluşturucu veya paylaşılmış kullanıcıya bütün kolonları güncelleme izni veriyor (`supabase/migrations/20260904_quote_team_visibility.sql:39-81`). Durum bazlı kolon koruması veya geçiş trigger'ı yok. Böylece teklifi düzenleyebilen kişi onu doğrudan `accepted`, `rejected` veya `cancelled` yapabilir.

Ek olarak Kanban ile `accepted` yapılırken mutabakat diyaloğu atlanıyor ve varsayılan teklif tutarı kabul tutarı olarak yazılıyor (`uzalteklif/lib/screens/quotes_page.dart:625-662`). Bu, kullanıcıya sorulan kabul tutarı/notu akışıyla çelişiyor.

**Öneri:** Teklif durum değişimini de `transition_quote` RPC'sine taşıyın. Rol matrisi ve geçişler sunucuda uygulanmalı. “Kazanıldı” yalnız yetkili rol tarafından, kabul tutarı + para birimi + kur + kabul kaynağı + müşteri kanıtı ile yapılabilmeli. Kanban yalnız aynı RPC'yi çağırmalıdır.

### P0.4 - Servis formu RLS politikaları kritik derecede geniş

`migration_service_forms.sql` içindeki yorum “Admin/Manager iptal edebilir” diyor; gerçek update policy ise bütün authenticated kullanıcılara `USING (true) WITH CHECK (true)` veriyor (`migration_service_forms.sql:128-134`). Form insert policy de tüm authenticated kullanıcılara her ticket için form oluşturma izni veriyor (`121-126`). Authenticated select policy bütün formları okutuyor (`99-104`); ticket/partner kapsamı yok.

Anon update policy yalnız eski durumun `pending`, yeni durumun `signed` olmasını kontrol ediyor (`106-119`). Değiştirilebilecek kolonları sınırlamıyor ve sunucu tarafında:

- zorunlu maddelerin gerçekten işaretlendiği,
- imzanın geçerli PNG/boyut sınırında olduğu,
- formun süresinin dolmadığı,
- token sahibinin doğru müşteri olduğu,
- `template_id`/`ticket_id` gibi alanların değişmediği

doğrulanmıyor.

**Öneri:** Anon tablo update'ini kaldırın. `sign_service_form(public_token, payload)` adlı `SECURITY DEFINER` RPC/Edge Function kullanın. Yalnız izin verilen alanları yazsın, eski ve yeni satırı kilitlesin, şablon snapshot'ından zorunlu maddeleri doğrulasın, boyut/rate limit uygulayıp audit event oluştursun. Authenticated politikaları ticket erişimi ve `AppPermission` eşdeğeri sunucu fonksiyonlarıyla sınırlandırılmalı.

### P0.5 - İmza dosyaları herkese açık ve anonim yükleme sınırsız

`service-signatures` bucket'ı public oluşturuluyor; herkes okuyabiliyor ve anonim kullanıcı bucket içinde herhangi bir nesne adıyla yükleme yapabiliyor (`migration_service_forms.sql:139-155`). Form ID bilinmese bile bucket kötüye kullanılabilir; imzalar kişisel veri olarak public URL ile açılabilir.

Ayrıca aynı imza hem public Storage'a hem base64 olarak DB satırına yazılıyor (`lib/services/service_form_service.dart:174-190`). Storage upload başarılı, DB update başarısız olursa sahipsiz dosya kalıyor. `customerIp` modelde var ama public sayfa çağrıda IP göndermediği için pratikte boş kalıyor (`lib/pages/public_service_form_page.dart:132-137`).

**Öneri:** Bucket private olmalı. Yükleme yalnız sunucu fonksiyonu üzerinden, `form_id/random-name` kontrollü yolu, MIME/PNG doğrulaması ve küçük boyut limitiyle yapılmalı. DB yalnız private object path + hash saklamalı; görüntüleme kısa ömürlü signed URL ile olmalı. Tek saklama kaynağı seçilmeli.

### P0.6 - Servis ön koşul formu imzalı halde yeniden açılamıyor ve delil sabit değil

Anon select policy yalnız `status = 'pending'` kayıtları gösteriyor (`migration_service_forms.sql:108-112`). Public sayfada imzalı ve iptal edilmiş formu gösterme dalları var (`lib/pages/public_service_form_page.dart:68-83`), fakat anonim kullanıcı imzadan sonra sayfayı yenilediğinde bu kaydı artık select edemez. Kullanıcı “geçersiz link” görür.

Form satırı şablonun snapshot'ını tutmuyor; her görüntülemede canlı `service_form_templates` JOIN'i kullanılıyor (`lib/services/service_form_service.dart:100-105`, `149-156`). Şablon sonradan düzenlenirse geçmişte imzalanan belgenin içeriği de ekranda değişmiş görünür. Şablon pasif yapılırsa anonim join policy yüzünden gönderilmiş pending form açılamayabilir.

**Öneri:** Form oluşturulurken `template_version`, `content_snapshot`, `checkboxes_snapshot`, `terms_hash` kaydedin. Public token ile pending veya signed kayıt kontrollü şekilde okunabilsin; signed kayıt salt okunur makbuz/PDF göstermeli. İptal edilen form yalnız minimal iptal mesajı döndürmelidir.

### P0.7 - Atölye “imalat emri” yapılandırılmış üretim kaydı değil

İş listesindeki “Atölyeye Gönder” eylemi ilk uygun takımın ilk panosuna normal Kanban kartı açıyor (`lib/pages/ticket_list_page.dart:428-481`). İş türü, teknik özellikler ve kontrol listesi kart açıklamasına metin olarak yazılıyor. Özel bir `workshop_orders` tablosu veya `card_type` alanı yok; atölye kartları başlık/açıklama içindeki “atolye/uretim” kelimeleriyle bulunuyor (`lib/services/card_service.dart:181-229`). Bu sınıflandırma yanlış pozitif/negatif üretir.

Reçete düzenlenince kart açıklaması tamamen yeni bir metin + gömülü JSON ile değiştiriliyor (`lib/pages/workshop_recipe_page.dart:262-305`). İlk dispatch açıklamasındaki müşteri, işlem türü, teknik özellikler ve altı maddelik checklist korunmuyor. Checklist yalnız `[ ]` metnidir; kim, ne zaman, hangi kanıtla tamamladı bilgisi tutulmaz.

Kart durumları (`TODO/DOING/DONE/SENT`) ile ana iş emri durumları birbirinden bağımsızdır. `updateCardStatus` ana ticket'ı güncellemez (`lib/services/card_service.dart:405-440`). Bu nedenle atölyede “Sevke Hazır/Gönderildi” görünen kartın ana işi hâlâ `open`, veya ana iş `done` iken üretim kartı `TODO` olabilir.

**Öneri:** Kanban kartını üretim kaydının kendisi değil, görünüm/projeksiyon olarak kullanın. Ayrı tablolar:

- `workshop_orders`
- `workshop_order_items`
- `workshop_recipe_versions`
- `workshop_check_items`
- `workshop_check_results`
- `workshop_material_reservations`
- `workshop_events`

Üretim durum geçişini sunucu RPC'si yönetsin; Kanban kartı aynı olaydan güncellensin. Bir ticket için aynı türde açık üretim emrine unique partial index konmalıdır.

### P0.8 - Gerçek sevkiyat modeli yok

Mevcut yapıda “sevk” bir Kanban durumu (`CardStatus.sent`) veya ticket durumu (`panel_done_sent`) olarak temsil ediliyor. Aşağıdaki zorunlu operasyon verileri için kayıt modeli bulunmuyor:

- sevkiyat numarası ve irsaliye numarası,
- hangi üretim/teklif kaleminden kaç adet gönderildiği,
- kısmi sevkiyat,
- seri numaraları,
- paket/koli bilgisi,
- taşıyıcı ve takip numarası,
- sevk eden/teslim alan,
- çıkış ve teslim zamanı,
- sevk öncesi fotoğraf ve evrak,
- hasarlı/eksik teslim istisnası,
- iade veya yeniden sevk.

**Öneri:** `shipments`, `shipment_items`, `shipment_packages`, `shipment_events`, `delivery_confirmations` tabloları eklenmeli. “Shipped” geçişi, en az bir shipment kaydı ve miktar dengesi olmadan yapılamamalıdır.

### P0.9 - Mevcut müşteri formu devreye alma ve kapanış kabul formu değildir

`ServiceFormTemplate` ve public sayfa metinleri açıkça **servis ön koşullarını** ve servis çağırma talebini temsil ediyor. Buton “Kabul Ediyorum ve Servis Çağırıyorum” diyor (`lib/pages/public_service_form_page.dart:727-779`). Bu belge:

- devreye alma test sonuçlarını,
- ölçülen değerleri,
- yazılım/firmware sürümlerini,
- I/O testlerini,
- alarm/senaryo sonuçlarını,
- eğitim ve doküman teslimini,
- açık kalan maddeleri,
- garanti başlangıcını,
- nihai müşteri kabulünü

tutmuyor. `CommissioningStep` yalnız marka/model rehber adımıdır; ticket'a bağlı bir çalıştırma sonucu değildir (`lib/models/commissioning_step.dart`).

**Öneri:** Ön koşul onayı ile devreye alma protokolünü ayırın:

1. `pre_service_acknowledgement`: ziyaret öncesi müşteri hazırlığı.
2. `commissioning_session`: sahada gerçekten yürütülen devreye alma.
3. `commissioning_check_result`: adım başına sonuç/değer/fotoğraf.
4. `customer_acceptance`: tamamlanan işin müşteri kabulü veya çekince listesi.
5. `closeout`: yönetici kapanışı ve belge paketi.

### P0.10 - Kapanış kapıları ve `done/archived` anlamı tutarsız

Kanonik yaşam döngüsü `done -> archived` diyor (`lib/models/ticket_status.dart:97-115`, `docs/ticket-lifecycle.md`). Fakat “Arşivlenmiş İşler” ekranı yalnız `status = 'done'` kayıtlarını çekiyor (`lib/pages/archived_tickets_page.dart:64-93`). Gerçek `archived` durumuna alınan kayıt bu ekranın dışında kalır.

`done` geçişi için müşteri imzası, teknisyen imzası, kullanılan malzeme, açık arıza, atölye kontrolü, sevk teslimi, devreye alma sonucu veya kapanış PDF'i zorunlu değil. Ekran yalnız “İmza ve evrakları tamamlayıp arşive alın” şeklinde öneri metni gösteriyor; kural uygulamıyor (`lib/pages/ticket_detail_page.dart:2721-2751`).

**Öneri:** Anlamları netleştirin:

- `completed`: teknik çalışma bitti, kapanış kontrolleri bekleniyor.
- `closed`: bütün zorunlu kapılar tamam, finansal/operasyonel kapanış yapıldı.
- `archived`: salt okunur saklama/retention durumu; günlük iş durumundan ayrı `archived_at` olabilir.

Arşiv ekranı `closed_at is not null` veya seçilen kesin kurala göre çalışmalıdır. `status` ile `is_archived/archived_at` aynı kavramı iki farklı şekilde temsil etmemelidir.

## P1 - Yüksek öncelikli yapısal sorunlar

### P1.1 - Üç ayrı ve senkronize olmayan durum alanı var

Ana ticket'ta `status`, proje işleri için ayrıca `project_status`, atölye kartında ayrıca `CardStatus` bulunuyor. `project_status` için `planned/in_progress/waiting/testing/missing/done/cancelled` listesi var (`supabase/migrations/20260620_job_templates.sql:36-52`). Yeni proje kaydında bu alan kısmen ticket `status` değerine çevriliyor (`lib/pages/new_ticket_page.dart:493-507`), edit ekranında ikisi ayrıca yazılıyor (`lib/pages/edit_ticket_page.dart:796-819`).

Bu model aynı iş için çelişkili gerçekler üretir. Örneğin ticket `open`, project `done`, workshop `TODO` olabilir.

**Öneri:** Genel iş aşaması tek kanonik alan olsun. Üretim, sevkiyat ve devreye alma alt süreçleri kendi durumlarını tutsun; ana iş aşaması bu alt süreçlerin olaylarıyla kontrollü ilerlesin. `project_status` ya kaldırılmalı ya da yalnız proje alt planının durumu olarak açıkça ayrılmalıdır.

### P1.2 - Edit ekranı geçerli durumları bozabiliyor

Edit ekranı yalnız `open/done/archived/draft/cancelled` durumlarını geçerli sayıyor. `in_progress`, `panel_done_stock` ve `panel_done_sent` kayıtlarını açınca local değeri `open` yapıyor (`lib/pages/edit_ticket_page.dart:455-459`) ve kaydederken bunu DB'ye yazıyor (`796-803`). Böylece yalnız bir alan düzenlemek isteyen kullanıcı iş akışını istemeden geriye alabilir.

**Öneri:** Edit formu status yazmamalı; durum yalnız transition servisiyle değişmeli. En azından bütün kanonik durumları `TicketStatus` kaynağından okumalıdır.

### P1.3 - Durum anahtarları farklı ekranlarda eskimiş

`ticket_list_page.dart` hâlâ `panel_done_waiting_stock`, `stock_waiting`, `panel_done_waiting_service`, `service_required`, `sent_to_service` gibi kanonik modelde olmayan anahtarları renklendiriyor (`1350-1404`). Dashboard da eski `panel_done_waiting_stock` anahtarını sorguluyor. Aynı dosyada birden fazla status label/color fonksiyonu var.

Sonuç: gerçek `panel_done_stock` veya `panel_done_sent` bazı listelerde ham anahtar, yanlış renk ya da yanlış sayaçla görünür.

**Öneri:** Bütün UI/PDF/raporlar `TicketStatus` üzerinden label, renk ve sıra alsın. Eski anahtarlar için tek seferlik data migration + geçici normalize fonksiyonu kullanın.

### P1.4 - Yeni iş emri oluşturma atomik değil ve müşteri çoğaltıyor

Yeni iş ekranı her kayıtta önce yeni `customers` satırı açıyor, sonra varsa dosyayı public URL ile Storage'a yüklüyor, en son ticket insert ediyor (`lib/pages/new_ticket_page.dart:381-555`). Ticket insert başarısız olursa müşteri ve dosya sahipsiz kalabilir. Aynı müşteri her işte yeniden oluşturulur; teklif uygulamasındaki `customer_accounts/cari_id` ile ilişki kurulmaz.

**Öneri:** Ortak bir `customer_accounts` ana kaydı ve adres/kişi alt kayıtları kullanın. İş oluşturmayı RPC ile transaction içinde yapın. Dosya önce temporary path'e yüklenip başarılı transaction sonrası bağlanmalı; başarısız akışlar için cleanup job olmalıdır.

### P1.5 - Atölyeye gönderim deterministik değil ve tekrar çalıştırılabilir

Ekran seçilen takımın `boards.first` panosunu kullanıyor (`lib/pages/ticket_list_page.dart:428-481`). “İlk pano”nun atölye panosu olduğuna dair garanti yok. Aynı ticket için butona tekrar basılarak birden fazla imalat kartı oluşturulabilir.

**Öneri:** Takım/pano üzerinde `board_type = workshop` veya yapılandırılmış default ID kullanın. `workshop_orders(ticket_id, order_type)` üzerinde açık kayıt için unique partial index ekleyin. UI mevcut kaydı açmalı; çoğaltmamalı.

### P1.6 - Atölye reçetesi ölçülebilir ve versiyonlu değil

Pano genişliği, yükseklik, güç gibi alanlar metin olarak tutuluyor. Birim, min/max, tip, ürün/seri ilişkisi, revizyon, onaylayan ve değişiklik gerekçesi yok. PDF çıktısı o an controller'daki değerlerden üretiliyor; DB'deki sabit bir reçete versiyonuna referans vermiyor.

**Öneri:** Reçete her kayıtta immutable revision üretmeli. `numeric_value`, `unit`, `catalog_product_id`, `required_quantity`, `revision_no`, `approved_by`, `approved_at` alanları olmalı. Üretime alma yalnız onaylı reçete revizyonuyla mümkün olmalıdır.

### P1.7 - Stok sürece bağlanmamış

Stok ve zimmet modülleri gelişmiş olsa da yeni iş emri açılırken otomatik stok düşme kodu bilinçli olarak kapatılmış; kullanıcı daha sonra manuel parça ekliyor (`lib/pages/new_ticket_page.dart:566-578`). Kabul edilen teklif satırlarından ihtiyaç listesi veya rezervasyon üretilmiyor. Atölye reçetesi ile `ticket_parts` arasında bağ yok.

**Öneri:** Aşamaları ayırın:

- Teklif kabulü: talep/öngörü (`job_material_requirements`).
- Planlama: rezervasyon (`stock_reservations`).
- Atölye/saha kullanımı: gerçek tüketim (`stock_movements`).
- İade/fire: ayrı hareket.

Stok, iş açılınca körlemesine düşmemeli; rezervasyon ve fiili tüketim ayrı olmalıdır.

### P1.8 - İmza işleminde yetki ve kanıt bütünlüğü zayıf

`SignaturePage` ticket'ı doğrudan güncelliyor ve servis/audit katmanını atlıyor (`lib/pages/signature_page.dart:167-223`). Müşteri imzası alınırken o an giriş yapmış personelin profil imzası otomatik olarak ticket'a kopyalanıyor (`190-205`); bu, personelin aynı anda gerçekten imza attığı anlamına gelmez. İmza sonrası hangi PDF/metnin kabul edildiği hash ile bağlı değil.

**Öneri:** İmzayı bir ticket kolonunu değiştirmek yerine `signatures`/`acceptance_signatures` immutable tablosuna olay olarak ekleyin. Belge snapshot ID/hash, imzalayan rolü, yöntem, zaman, cihaz/oturum bilgisi ve gerekirse OTP kaydı tutun. Personel profil imzasını otomatik “o işin imzası” saymayın.

### P1.9 - Servis formu imzalandığında süreç ilerlemiyor ve iç ekip bilgilendirilmiyor

`signForm()` yalnız form satırını güncelliyor. İş emrine event eklemiyor, planlama kapısını açmıyor, bildirim/outbox oluşturmuyor (`lib/services/service_form_service.dart:164-190`). Personel ancak ekranı yenilerse durumu görür.

**Öneri:** İmza RPC'si `service_form_signed` domain event'i üretmeli. Outbox worker ilgili sorumluya bildirim göndermeli ve gerekiyorsa `preconditions_ready` milestone'unu tamamlamalıdır.

### P1.10 - Domain ve ortam URL'leri kod içine dağılmış

Servis formu linkleri `.com/is-takip` olarak üç ayrı yerde sabit (`lib/pages/ticket_list_page.dart:656`, `lib/pages/ticket_detail_page.dart:454`, `756`). Teklif/WhatsApp linkleri başka yerlerde `.info` kullanıyor; teklif PDF config varsayılanı ise `uzalteknik.com/t` (`uzalteklif/lib/config/app_config.dart`).

Bu durum test bağlantısının canlıya veya canlı bağlantının teste gitmesine neden olabilir.

**Öneri:** `PUBLIC_APP_BASE_URL`, `PUBLIC_SERVICE_FORM_BASE_URL`, `PUBLIC_QUOTE_BASE_URL` tek config katmanından gelmeli. Build sırasında ortam adı görünür olmalı. `.info` ve `.com` ayrımı repo kuralına uygun uygulanmalıdır.

### P1.11 - Veri erişimi sayfalara dağılmış

Kök `lib/pages` altında doğrudan Supabase/veri erişimi yapan yaklaşık 20 sayfa, teklif ekranlarında yaklaşık 11 sayfa var. Ticket create/edit/delete, imza ve form gönderimi gibi kritik yazmaların bir kısmı service/repository sınırını atlıyor.

Bu, aynı işlemin farklı ekranlarda farklı yetki, log, bildirim ve validasyonla çalışmasına neden oluyor.

**Öneri:** Önce kritik command'ları merkezileştirin: `AcceptQuote`, `CreateJobFromQuote`, `DispatchToWorkshop`, `CompleteWorkshop`, `CreateShipment`, `CompleteCommissioning`, `AcceptByCustomer`, `CloseJob`. Sayfalar yalnız bu command servislerini çağırmalıdır.

### P1.12 - SQL kaynakları dağınık ve ortamı yeniden kurma güveni düşük

Repo kökünde 35 SQL, `supabase/migrations` altında 12 SQL, `uzalteklif/supabase/migrations` altında 20 SQL bulunuyor. `tickets` ana tablosunu ve temel RLS politikalarını sıfırdan oluşturan kanonik bir migration `supabase/migrations` içinde bulunamadı; çoğu operasyon migration'ı repo kökünde. Servis formu migration'ı da kökte ve normal Supabase CLI migration zincirinin dışında.

`CHECK ... NOT VALID` kullanımı eski satırları doğrulamadan bırakıyor; sonraki `VALIDATE CONSTRAINT` adımı görünmüyor.

**Öneri:** Tek bir kanonik migration dizini belirleyin. Mevcut production şemasından baseline çıkarın, sonra forward-only migration'lara geçin. Her migration için preflight/postflight ve `validate constraint` adımı ekleyin. CI boş veritabanına bütün migration'ları uygulayıp şema testleri çalıştırmalıdır.

## P2 - Orta öncelikli kalite ve bakım sorunları

### P2.1 - Çok büyük ekran ve servis dosyaları

Örnekler:

- `lib/pages/ticket_detail_page.dart`: yaklaşık 6.349 satır.
- `lib/pages/ticket_list_page.dart`: yaklaşık 3.326 satır.
- `lib/services/ticket_pdf_service.dart`: yaklaşık 2.700 satır.
- `uzalteklif/lib/screens/quote_editor_page.dart`: yaklaşık 5.523 satır.
- `uzalteklif/lib/screens/quote_review_page.dart`: yaklaşık 2.453 satır.

Bu dosyalarda domain kuralı, veri erişimi, URL oluşturma, PDF üretimi ve UI birlikte bulunuyor. Değişikliklerin yan etkisini anlamak zorlaşıyor.

**Öneri:** Dosya küçültmeyi amaç değil sonuç yapın. Önce command/query servislerini ve domain modellerini çıkarın; sonra ekranları aşama bazlı widget'lara ayırın. Büyük çaplı tek seferlik rewrite yapmayın.

### P2.2 - Kaynak metinlerinde gerçek encoding bozulmaları var

UTF-8 olarak okunduğunda bazı kaynaklarda `MÃ¼ÅŸteri`, `BaÅŸlÄ±k` ve `Ã¯Â¿Â½` benzeri bozuk metinler gerçekten dosyada bulunuyor. Örnekler `lib/pages/new_ticket_page.dart`, `lib/pages/ticket_list_page.dart`, `pubspec.yaml` ve bazı normalize fonksiyonlarıdır. Bazıları yorum, bazıları kullanıcıya görünen string'dir.

**Öneri:** Önce kullanıcıya görünen metinleri envanterleyin. Otomatik tüm-repo dönüşümü yapmadan, testlerle kontrollü düzeltin. DB'de geçmişten bozuk metin varsa ayrıca veri temizleme migration'ı planlayın.

### P2.3 - Silme kalıcı ve belge zincirini yok edebiliyor

İş listesi ve arşiv ekranlarında doğrudan hard delete var (`lib/pages/ticket_list_page.dart:698-727`, `lib/pages/archived_tickets_page.dart:136-170`). Üretim reçetesi de kart delete ile tamamen silinebiliyor (`lib/pages/workshop_recipe_page.dart:119-160`).

**Öneri:** Operasyon kayıtlarında hard delete yerine `voided_at`, `voided_by`, `void_reason` kullanın. İlişkili PDF/snapshot/audit kayıtları korunmalı. Hard delete yalnız veri koruma prosedürü ve üst düzey yönetici/DB işlemi olmalıdır.

### P2.4 - Bildirim ve audit işlemleri atomik değil

Ticket update sonrası bildirim ve activity log fire-and-forget olarak çalışıyor; hata ana işlemi geri almıyor (`lib/services/ticket_service.dart:79-126`). Bu kullanıcı deneyimi açısından anlaşılır, fakat kritik olayın bildirimi kaybolabilir.

**Öneri:** Transaction içinde `outbox_events` satırı oluşturun. Ayrı worker/Edge Function retry ile bildirim, PDF arşiv ve entegrasyonları işlesin. Event'in işlendiği/başarısız olduğu görülebilsin.

### P2.5 - Termin ve SLA modeli yetersiz

Ticket'ta tek `planned_date`, projede ayrıca start/due date, Kanban kartında due date var. Aşama bazlı hedef/sapma, müşteri randevusu, sevk ETA ve commissioning tarihi ayrılmamış.

**Öneri:** `job_milestones` tablosunda planlanan/gerçekleşen tarih, sorumlu, durum ve gecikme nedeni tutun. Dashboard bu tablodan SLA üretmeli.

### P2.6 - İş türleri için koşullu akış tanımlı değil

Her kabul edilen iş atölye, sevkiyat ve devreye alma gerektirmeyebilir. Bakım işi doğrudan saha servisine; yalnız malzeme satışı sevkiyata; pano işi atölye + sevkiyat + devreye almaya gidebilir.

**Öneri:** Teklif/iş kapsamından `required_stages` üretin. Süreç motoru opsiyonel aşamaları atlayabilsin; kullanıcı keyfi status atlamasın.

## 3. Önerilen hedef süreç

```text
Teklif Taslak
  -> İç Onay
  -> Müşteriye Gönderildi
  -> Müşteri Kabulü / Kazanıldı
       [Atomik: kabul snapshot + iş emri + kapsam kalemleri]
  -> İş Planlama
       [sorumlu, termin, gerekli aşamalar, malzeme ihtiyacı]
  -> Tedarik / Stok Rezervasyonu (gerekiyorsa)
  -> Atölye İmalat (gerekiyorsa)
       [reçete onayı -> üretim -> QC -> sevke hazır]
  -> Sevkiyat (gerekiyorsa)
       [paket/seri/miktar -> çıkış -> teslim]
  -> Saha Hazırlık Onayı (gerekiyorsa)
  -> Kurulum / Devreye Alma
       [test adımları + ölçümler + fotoğraflar + açık maddeler]
  -> Müşteri Kabulü
       [kabul / çekinceli kabul / ret]
  -> Teknik Tamamlama
  -> Yönetici Kapanışı
       [belge paketi + mali kontrol + garanti başlangıcı]
  -> Salt Okunur Arşiv
```

### Önerilen ana iş durumları

| Durum | Anlam | Zorunlu çıkış kapısı |
| --- | --- | --- |
| `intake` | Tekliften iş doğdu | Kaynak teklif snapshot'ı mevcut |
| `planning` | Sorumlu ve kapsam planlanıyor | Sorumlu, termin, gerekli aşamalar |
| `procurement` | Eksik malzeme bekleniyor | Rezervasyon/tedarik tamam |
| `workshop` | Atölye işi sürüyor | Üretim emri QC onaylı |
| `ready_to_ship` | Sevke hazır | Paket/seri/miktar doğrulandı |
| `shipped` | Sevk edildi | Shipment kaydı ve çıkış kanıtı |
| `onsite` | Saha çalışması başladı | Ziyaret/ekip kaydı |
| `commissioning` | Devreye alma testleri | Zorunlu testlerin tamamı başarılı/istisna onaylı |
| `customer_acceptance` | Müşteri sonucu bekleniyor | İmzalı kabul veya yetkili istisna |
| `completed` | Teknik iş bitti | Açık teknik blocker yok |
| `closed` | Operasyonel/mali kapanış | Kapanış checklist + final PDF paketi |
| `cancelled` | İptal | Gerekçe ve yetkili onayı |
| `on_hold` | Kontrollü bekleme | Bekleme nedeni ve tekrar değerlendirme tarihi |

Bu liste doğrudan tek enum yazıp her işe zorla uygulanmamalı. `required_stages` ile bakım, yalnız sevk, yalnız saha ve atölyeli proje varyasyonları desteklenmelidir.

## 4. Önerilen veri modeli

Mevcut `tickets` tablosunu koruyarak evrimsel geçiş önerilir; baştan ayrı bir ERP yazmak gereksizdir.

### `tickets` için temel ekler

```text
source_quote_id          text unique null
source_quote_revision_id / source_quote_snapshot_id
customer_account_id     uuid/text
workflow_key            text
workflow_version        integer
status_version          integer
required_stages         text[] veya jsonb
current_stage           text
completed_at            timestamptz
closed_at               timestamptz
closed_by               uuid
close_reason            text
archived_at             timestamptz
```

### Yeni operasyon tabloları

| Tablo | Amaç |
| --- | --- |
| `quote_acceptances` | Müşteri kabul kaynağı, tutar, kur, revizyon snapshot/hash |
| `job_scope_items` | Kabul edilen teklif kalemlerinin iş kapsamındaki sabit kopyası |
| `job_stage_events` | Append-only durum/aşama geçmişi |
| `job_milestones` | Planlanan ve gerçekleşen aşama tarihleri |
| `workshop_orders` | Ticket'a bağlı gerçek üretim emri |
| `workshop_recipe_versions` | Versiyonlu ve onaylı reçete |
| `workshop_check_results` | QC maddesi, sonuç, ölçüm, kişi, zaman, kanıt |
| `job_material_requirements` | Planlanan malzeme ihtiyacı |
| `stock_reservations` | İş/üretim için ayrılan stok |
| `shipments` / `shipment_items` | Kısmi/tam sevkiyat ve kalem miktarları |
| `commissioning_sessions` | Saha devreye alma oturumu |
| `commissioning_check_results` | Test/ölçüm/adım sonuçları |
| `customer_acceptances` | Nihai kabul, çekince veya ret |
| `job_closeouts` | Kapanış checklist ve yönetici onayı |
| `document_snapshots` | Belge türü, revizyon, hash, storage path, üretim zamanı |
| `outbox_events` | Güvenilir bildirim/arşiv/entegrasyon kuyruğu |

### Kanban'ın rolü

Kanban kaldırılmamalı; fakat “source of truth” olmamalıdır. `workshop_order` veya `job_stage` olayından kart yaratılan/güncellenen bir görünüm olmalıdır. Kartın serbest metninden üretim emri keşfedilmemelidir.

## 5. Aşama kapıları

### Teklif kabul kapısı

- Durum müşteriye gönderilmiş olmalı.
- Kullanıcı kabul yetkisine sahip olmalı.
- Kabul tutarı, para birimi ve kur zorunlu olmalı.
- Kabul edilen revizyon sabitlenmeli.
- Müşteri kabul yöntemi (`signed_pdf`, `email`, `portal`, `manual_with_reason`) tutulmalı.
- `manual_with_reason` yalnız yönetici ve gerekçeyle olmalı.

### Atölyeye alma kapısı

- Onaylı iş kapsamı olmalı.
- Atölye gerektiren kalemler seçilmiş olmalı.
- Reçete revizyonu onaylı olmalı.
- Sorumlu usta ve termin belirlenmeli.
- Kritik malzeme rezervasyonu veya onaylı eksik istisnası olmalı.

### Üretim tamamlama kapısı

- Bütün zorunlu QC maddeleri tamamlanmış olmalı.
- Test ölçümleri limit içinde olmalı veya NCR/istisna onayı bulunmalı.
- Son ürün fotoğrafı ve seri/pano etiketi olmalı.
- Kullanılan malzeme tüketimleri işlenmiş olmalı.
- Usta + kalite/yönetici ayrık onayı uygulanmalı.

### Sevkiyat kapısı

- Sevke hazır miktar gönderilen miktardan az olmamalı.
- Paket/seri numarası ve sevk evrakı bulunmalı.
- Çıkış yapan kişi ve zaman sunucudan yazılmalı.
- Kısmi sevk varsa kalan miktar açık kalmalı.

### Devreye alma kapısı

- Saha ön koşul formu gerekiyorsa imzalı olmalı.
- Zorunlu test adımları sonuçlanmalı.
- Ölçümler, yazılım/parametre yedeği ve fotoğraflar bağlanmalı.
- Başarısız test için açık aksiyon/istisna olmalı.

### Kapanış kapısı

- Açık workshop/shipment/commissioning kaydı olmamalı.
- Kullanılan parça ve seri hareketleri tamamlanmalı.
- Müşteri kabulü veya yetkili çekince/ret süreci bulunmalı.
- Teknisyen ve müşteri imzası kurala göre mevcut olmalı.
- Final servis raporu ve ekleri arşivlenmiş olmalı.
- Kapanış nedeni, kapatan ve server timestamp tutulmalı.

## 6. PDF ve belge sistemi analizi

### Mevcut güçlü taraflar

- Teklif PDF'i `MultiPage`, yerel NotoSans fontu, header/footer, sayfa numarası, uzun teklif ve uzun not desteği içeriyor.
- Teklif PDF testleri 6 Eylül 2026 incelemesinde çalıştırıldı: 5/5 geçti.
- 120 kalemli stres testi ve uzun çok satırlı not testi var.
- İş emri PDF'i müşteri/partner varyantları, servis notları, fotoğraflar ve iki imza alanı üretiyor.
- Bazı PDF servisleri sayfa numarası ve Türkçe font kullanıyor.

### PDF tarafındaki önemli eksikler

#### İş emri PDF'i kapanış dosyası değil

`TicketPdfService.generateSingleTicketPdfBytes` yalnız ticket + filtrelenmiş ticket notes sorguluyor (`lib/services/ticket_pdf_service.dart:25-112`). Şunları sorgulamıyor veya belgeye koymuyor:

- `ticket_parts` / kullanılan malzemeler,
- servis ön koşul formları ve hangi maddelerin kabul edildiği,
- atölye reçete revizyonu ve QC sonucu,
- shipment/teslim kaydı,
- commissioning test sonuçları,
- bağımsız fault record detayları,
- kabul edilen teklif/revizyon/tutar ilişkisi,
- kapanış checklist'i.

Servis notları 800 karakterde kesiliyor (`lib/services/ticket_pdf_service.dart:2476-2530`). Bu bir özet PDF için kabul edilebilir; “resmi final dosya” için veri kaybıdır. Tam metin ayrı ek veya yapılandırılmış tablo olarak konmalıdır.

İmza bloğu `MultiPage.footer` içinde üretildiği için her sayfada tekrar edebilir (`lib/services/ticket_pdf_service.dart:1903-1924`, `2597-2698`). İmza, içerikten bağımsız tekrar eden footer değil, yalnız final onay sayfasında belge hash/revizyonuyla birlikte olmalıdır.

#### Atölye reçete PDF'i üretim belgesi standardında değil

Reçete PDF'i ekran State controller'larından tek `pw.Page` ile üretiliyor (`lib/pages/workshop_recipe_page.dart:316-359`). Uzun tablo/notta taşma riski vardır; `MultiPage` kullanılmıyor. Yerel Türkçe font, logo, belge/revizyon numarası, sayfa numarası, oluşturan/onaylayan, tarih, malzeme listesi, checklist sonuçları, QR/hash ve imzalar yok. Testi de yok.

#### Kabul edilmiş teklif PDF'i müşteri kabul kanıtı gibi algılanabilir

Teklif `accepted` olduğunda PDF mutabakat bloğu üretiyor; ancak mevcut kabul bir personelin manuel menüsü veya Kanban sürüklemesiyle oluşabiliyor. Bu nedenle PDF üzerindeki “kazanıldı/mutabakat” bilgisi müşteri tarafından doğrulanmış kabul kanıtı değildir.

Belgede açıkça `Kabul kaynağı`, `Müşteri tarafından onaylandı mı?`, `Kanıt ID`, `Kabul edilen revizyon/hash` ayrılmalıdır.

#### Arşiv gerçek kurumsal arşiv değil

Teklif PDF'i kaydedilince masaüstü application support dizinine sessizce kopyalanıyor (`uzalteklif/lib/services/pdf_archive_service.dart`). Hatalar yutuluyor, web tarafında eşdeğer arşiv yok, merkezi indeks/hash/retention bulunmuyor. Cihaz bozulursa arşiv kaybolabilir. Google Drive otomatik arşivleme yalnız yol haritasında bekleyen görevdir (`docs/project-roadmap-and-gdrive-backup.md`).

**Öneri:** PDF üretimini event/outbox ile merkezi hale getirin. Her final belge için:

- `document_type`, `entity_id`, `entity_version`,
- `generated_at`, `generated_by`,
- SHA-256,
- private storage path,
- Drive object ID/yedek durumu,
- supersedes/superseded_by,
- retention durumu

tutun. PDF yeniden üretilirse eski belgeyi ezmeyin; yeni revision oluşturun.

### Önerilen belge seti

| Belge | Tetikleyici | Zorunlu içerik |
| --- | --- | --- |
| Teklif PDF | Müşteriye gönderim | Revizyon, geçerlilik, ticari şartlar, kalemler, QR |
| Teklif Kabul Kaydı | Kabul | Kabul kaynağı, tutar/kur, snapshot hash, taraflar |
| İş Emri | İş oluşturma/plan onayı | Kaynak teklif, kapsam, sorumlular, aşamalar |
| Atölye Üretim Reçetesi | Reçete onayı | Versiyon, malzeme, ölçüler, şema ekleri, imzalar |
| Atölye QC Formu | Üretim tamam | Checklist, ölçümler, fotoğraflar, NCR/istisna |
| Sevk İrsaliye Eki | Sevk | Kalem/miktar/seri/paket/taşıyıcı/teslim bilgisi |
| Saha Ön Koşul Onayı | Ziyaret öncesi | Şablon snapshot, checkbox, müşteri imzası |
| Devreye Alma Protokolü | Commissioning tamam | Adım sonuçları, ölçüm, parametre, fotoğraf, açık maddeler |
| Müşteri Kabul Formu | Teslim/kabul | Kabul/çekince/ret, teslimler, imza, belge hash |
| Final Kapanış Paketi | `closed` | Yukarıdaki belgelerin indeksi + nihai servis raporu |

### PDF test önerileri

- Her belge için en az bir unit generation testi.
- 0, 1, çok ve aşırı uzun kalem/not testleri.
- Türkçe karakter ve bozuk veri fallback testi.
- PDF metin extraction ile zorunlu başlık/alan kontrolü.
- Render edilmiş PNG golden testi: taşma, siyah kutu, font, imza, tablo.
- Her sayfada header/footer/sayfa numarası testi.
- İmzanın yalnız final sayfada ve doğru hash ile bulunması testi.
- Aynı snapshot'ın deterministik içerik sürümü testi.

İnceleme sırasında teklif PDF örnekleri başarıyla üretildi (`preview_quote.pdf`, `preview_material_request_tr.pdf`). Ortamda Poppler/`pdftoppm`, Python ve alternatif PDF raster aracı bulunmadığından PNG'ye render ederek görsel doğrulama yapılamadı. Bu nedenle “görsel kusur yok” sonucu verilmemiştir; kod ve üretim testleri geçmiştir.

## 7. Yetki modeli önerisi

Yetkiler yalnız rol + ekran görünürlüğü olmamalı; eylem, kayıt kapsamı ve aşamaya göre değerlendirilmelidir.

| Eylem | Önerilen yetki |
| --- | --- |
| Teklif düzenleme | Oluşturan/paylaşılan satış kullanıcısı; terminal durumda kilitli |
| Teklif iç onay | Finans/manager |
| Müşteriye gönderim | Satış + onay kapısı |
| Kazanıldı/kaybedildi | Manager/finans veya doğrulanmış müşteri portal yanıtı |
| İş emri oluşturma | Kabul RPC'si veya operasyon yöneticisi |
| Atölyeye sevk | Planlama/operasyon yetkisi |
| Reçete düzenleme | Atölye sorumlusu |
| Reçete onayı | Atölye yöneticisi/mühendis; hazırlayandan farklı kişi opsiyonu |
| QC tamam | Atölye kalite/yönetici |
| Sevkiyat çıkışı | Depo/sevkiyat rolü |
| Devreye alma sonucu | Atanmış teknisyen/mühendis |
| Müşteri kabulü | Public token + doğrulama veya iç istisna yetkisi |
| İş kapanışı | Manager/operasyon; kapılar başarılıysa |
| Void/hard delete | Sınırlı admin + zorunlu gerekçe/audit |

RLS fonksiyonları `can_view_job`, `can_edit_job`, `can_transition_job`, `can_sign_form` gibi tekrar kullanılabilir kurallar olmalı. UI aynı kuralları kullanıcı deneyimi için yansıtsa da güvenlik DB'de kalmalıdır.

## 8. Test, analiz ve CI bulguları

### Çalıştırılan kontroller

| Kontrol | Sonuç |
| --- | --- |
| `uzalteklif/flutter test test/pdf_export_service_test.dart` | Başarılı, 5/5 |
| Teklif kritik 5 dosya hedefli `flutter analyze` | Başarılı, sorun yok |
| Kök `./run_local.bat test` | Başarısız |
| Kök kritik 7 dosya hedefli `flutter analyze` | Tamamlandı, 9 bulgu |
| Kök tam `flutter analyze` | 180 saniyede zaman aşımı |
| PDF PNG render | Araç eksikliği nedeniyle yapılamadı |

Kök test 374 px genişlikte `lib/pages/login_page.dart:300` satırındaki `Row` için sağa 44 px RenderFlex overflow ile başarısız oldu.

Kök hedefli analyzer, `ticket_pdf_service.dart` içinde 3 warning ve 6 info bildirdi: dead null-aware ifadeler, dead code, kullanılmayan element ve stil bulguları.

### CI gerçekte bütün kök testleri çalıştırmıyor

`run_local.ps1` test eylemi yalnız `test/widget_test.dart` çalıştırıyor. `.github/workflows/flutter_ci.yml` de kök uygulamada yalnız bu testi çalıştırıyor. Kök altında izin, kullanıcı erişimi ve PDF rol testi gibi başka testler olmasına rağmen CI kapsamına girmiyor. Ayrıca kök analyze adımı `continue-on-error: true`; analiz hatası pipeline'ı durdurmuyor.

Teklif uygulamasının CI işi bütün testleri çalıştırdığı için daha sağlıklı.

**Öneri:**

1. Kök CI `flutter test` çalıştırsın.
2. Analyze zorunlu gate olsun; yalnız bilinçli warning istisnaları lint config ile yönetilsin.
3. İki uygulama için ayrı coverage raporu ve minimum kritik-domain kapsamı eklensin.
4. Supabase local üzerinde RLS/RPC integration testleri çalışsın.
5. Teklif kabulünden kapanışa happy-path ve istisna-path testleri eklensin.

### Öncelikli süreç testleri

- Aynı teklif iki kez kabul edilince yalnız bir ticket oluşur.
- Yetkisiz satış kullanıcısı teklifi `accepted` yapamaz.
- `draft -> done` reddedilir.
- Atölye QC bitmeden `ready_to_ship` reddedilir.
- Kısmi sevkiyat ana işi tamamlamaz.
- Zorunlu commissioning adımı başarısızsa müşteri kabul aşaması açılmaz.
- İmzasız/kanıtsız iş `closed` olamaz.
- Public form zorunlu maddeler eksikken API üzerinden de imzalanamaz.
- İmzalı form yenilenince salt okunur makbuz görünür.
- Partner başka partnerin ticket/form/imzasını göremez.

## 9. Uygulama yol haritası

## Faz 0 - Güvenlik ve veri kaybı önleme (1-2 hafta)

- Servis formu RLS açıklıklarını kapat.
- Signature bucket'ı private yap ve anon doğrudan upload'ı kaldır.
- Quote status menüsü/Kanban için rol ve sunucu geçiş kontrolü getir.
- Ticket status update'ini tek servise/RPC'ye yönlendir.
- Edit ekranının geçerli aktif statüleri `open`a çevirmesini düzelt.
- `done/archived` arşiv ekranı çelişkisini düzelt.
- Hardcoded `.com/.info` URL'lerini config'e taşı.
- Kök CI bütün testleri çalıştırsın; login overflow düzelsin.

## Faz 1 - Tekliften tekil iş emri üretme (2-3 hafta)

- `source_quote_id`, snapshot ve `job_scope_items` migration'ı.
- `accept_quote_and_create_job` idempotent RPC.
- Ortak cari/müşteri eşleme stratejisi.
- Kabul rolü, tutar, para birimi, kur ve kanıt kuralları.
- Kabul ve iş oluşturma entegrasyon testleri.

## Faz 2 - Gerçek atölye üretim modeli (3-5 hafta)

- `workshop_orders`, recipe revisions, materials, QC results.
- Kanban'ı projection olarak bağla.
- Sorumlu/termin/duplicate prevention.
- Fotoğraflı bitirme, ölçüm ve iki aşamalı onay.
- Üretim reçetesi + QC PDF'leri ve testleri.

## Faz 3 - Stok rezervasyon ve sevkiyat (3-5 hafta)

- Teklif/iş kapsamından malzeme ihtiyacı.
- Rezervasyon, tüketim, iade, fire hareketleri.
- `shipments` ve kısmi sevkiyat.
- Seri/paket/taşıyıcı/teslim kanıtı.
- Sevk PDF'i ve miktar denge kontrolleri.

## Faz 4 - Devreye alma ve müşteri kabulü (3-5 hafta)

- Ön koşul formunu güvenli snapshot/token altyapısına taşı.
- Commissioning template + session + typed result modeli.
- Offline taslak/senkron stratejisi; sahada bağlantı kesintisini ele al.
- Müşteri kabul/çekince/ret ve açık madde takibi.
- Devreye alma ve kabul PDF'leri.

## Faz 5 - Kapanış, arşiv ve otomasyon (2-4 hafta)

- `job_closeouts` ve kapanış gate RPC.
- Final belge paketi ve immutable document snapshots.
- Outbox tabanlı bildirim, PDF üretimi ve retry.
- Google Drive merkezi yedekleme, hash ve yedek durum dashboard'u.
- Yönetim raporları: kazanılan teklif -> açık iş -> sevk -> kabul -> kapanış çevrim süresi.

## 10. Hemen yapılabilecek düşük riskli düzeltmeler

Tam veri modelini beklemeden aşağıdakiler hızla değer üretir:

1. `EditTicketPage` status listesini `TicketStatus`tan üretmek ve form save'den status alanını çıkarmak.
2. Arşiv ekranını seçilen kanonik kurala göre `done + archived` veya `closed_at` ile düzeltmek.
3. Liste/dashboard/PDF status label fonksiyonlarını `TicketStatus.labelOf` ile birleştirmek.
4. Atölye kartına en az `card_type = workshop` alanı eklemek; metin aramasını bırakmak.
5. Aynı ticket için açık atölye kartı kontrolü koymak.
6. Atölye reçetesi save sırasında ilk dispatch verilerini kaybetmemek.
7. Servis formu link base URL'sini config'e taşımak.
8. İmzalı formun reload davranışını düzeltmek.
9. Kök CI'da tüm testleri çalıştırmak ve analyze'ı zorunlu yapmak.
10. Ticket PDF'ine kullanılan malzeme tablosunu eklemek; sonra form/QC/sevkiyat/commissioning ile genişletmek.

## 11. Başarı ölçütleri

Sistem aşağıdakiler sağlandığında gerçekten uçtan uca kabul edilebilir:

- Her kazanılan teklif en fazla bir ana iş emrine izlenebilir.
- Her iş emri hangi teklif revizyonu ve müşteri kabul kanıtından doğduğunu gösterir.
- Her durum geçişi sunucuda yetki + mevcut durum + zorunlu kapılarla doğrulanır.
- Ana iş ile atölye/sevkiyat/devreye alma durumları çelişemez veya çelişki dashboard'da açık hata olarak görünür.
- Her malzeme planlama, rezervasyon ve tüketim aşamalarında izlenir.
- Kısmi sevkiyat ve kısmi kabul desteklenir.
- İmzalanan metin sonradan değişmez; snapshot/hash ile ispatlanır.
- Kapanmış iş silinemez/değiştirilemez; yalnız yetkili void/reopen prosedürü vardır.
- Final PDF paketi merkezi, versiyonlu, hash'li ve yedeklenmiş olur.
- CI bütün kritik testleri gerçekten çalıştırır ve başarısız analiz/test merge'i engeller.

## 12. Sonuç

Projenin “saçma” kalan kısmı tek tek ekranların tasarımı değil; **bir özelliğin başka bir özelliğin devamıymış gibi görünmesine rağmen veri ve işlem açısından devamı olmaması**dır. En net örnekler:

- “Kazanıldı” teklifinin iş emri üretmemesi,
- “Atölyeye gönderildi” işleminin üretim emri yerine metin tabanlı Kanban kartı üretmesi,
- “Sevke hazır/gönderildi” durumunun sevkiyat kaydı olmaması,
- “Servis formu”nun devreye alma/kapanış kabul formu sanılması,
- `done/archived` durumlarının ekranlarda farklı anlam taşıması,
- UI'da görünen geçiş kurallarının DB tarafından uygulanmaması.

Doğru yaklaşım baştan büyük bir ERP rewrite'ı değildir. Önce güvenlik ve geçişleri sunucu tarafında merkezileştirmek; sonra teklif kabulünden tekil iş üretmek; ardından atölye, sevkiyat, commissioning ve kapanışı ayrı ama bağlı alt süreçlere dönüştürmektir. Mevcut teklif, ticket, Kanban, stok, imza ve PDF kodları bu hedefte yeniden kullanılabilir; fakat gerçek kayıt kaynağı serbest metinler ve ekran State'i değil, versiyonlu domain kayıtları ve doğrulanmış geçiş komutları olmalıdır.

