# Tek Kişi ve Yapay Zekâ Destekli Teklif, Satış ve Cari Sistemi Çalışma Fazları

**Kaynak rapor:** `TEKLIF_SATIS_CARI_SISTEMI_PROFESYONELLESTIRME_RAPORU.md`  
**Plan tarihi:** 6 Eylül 2026  
**Uygulayıcı:** Tek kişi, sınırlı yazılım deneyimi, yapay zekâ destekli geliştirme  
**Amaç:** Analiz raporundaki önerileri güvenli, küçük, sıralı ve yapay zekâ ile uygulanabilir iş paketlerine dönüştürmek.

---

## 1. Bu planın önceki plandan farkı

Bu sürümde ayrı bir "Ürün keşfi ve ölçüm" fazı yoktur. Analiz raporundaki bulgular çalışma için yeterli kabul edilmiştir ve doğrudan uygulamaya geçilecektir.

Plan şu gerçeklere göre yeniden düzenlenmiştir:

- Projeyi tek kişi geliştirecek.
- Yazılım bilgisi sınırlı olduğu için değişikliklerin çoğu yapay zekâ yardımıyla yapılacak.
- Aynı anda birçok büyük modül geliştirilmeyecek.
- Her iş küçük, test edilebilir ve geri alınabilir olacak.
- Önce yanlış ve güvensiz davranışlar düzeltilecek.
- Sonra teklif hazırlama hızlandırılacak.
- CRM, müşteri portalı ve entegrasyonlar daha sonra yapılacak.
- Her faz sonunda çalışan bir sürüm korunacak.
- Yapay zekâya tek seferde bütün sistemi yeniden yazdırılmayacak.

Bu plan bir ekip sprint planı değil, tek geliştiricinin kontrollü ilerleme planıdır.

---

## 2. Gerçekçi zaman ve kapsam

Yapay zekâ kod yazma süresini azaltabilir; ancak veri modeli, test, hata ayıklama, Supabase migration, güvenlik ve canlıya alma sorumluluğunu ortadan kaldırmaz. Bu nedenle süreler yalnız kod üretme süresi olarak düşünülmemelidir.

### Yaklaşık süreler

| Teslim seviyesi | Fazlar | Net çalışma günü | Yarı zamanlı tahmin |
|---|---|---:|---:|
| Güvenli mevcut sürüm | Faz 1 | 8-15 gün | 3-5 hafta |
| Hızlı teklif hazırlama sürümü | Faz 1-3 | 35-55 gün | 3-5 ay |
| Profesyonel teklif MVP'si | Faz 1-5 | 75-120 gün | 6-10 ay |
| CRM ve raporlama dahil sistem | Faz 1-7 | 120-190 gün | 10-16 ay |

Bu tahminlere öğrenme, test, hata düzeltme ve yeniden çalışma payı dahildir. Haftada ayrılan zamana ve dış servis entegrasyonlarına göre süre değişebilir.

### Önerilen durma noktaları

Her şeyi tamamlamaya çalışmak yerine üç yayın hedefi kullanılmalıdır:

1. **Sürüm A - Güvenli teklif aracı:** Faz 1 tamamlanır.
2. **Sürüm B - Hızlı teklif aracı:** Faz 1-3 tamamlanır.
3. **Sürüm C - Profesyonel satış MVP'si:** Faz 1-5 tamamlanır.

Faz 6-7, temel teklif sistemi sahada sorunsuz çalıştıktan sonra yapılmalıdır.

---

## 3. Fazların genel sırası

| Faz | Ad | Ana sonuç | Tahmini net efor |
|---:|---|---|---:|
| 1 | Güvenli başlangıç ve acil doğruluk düzeltmeleri | Yanlış kayıt üretmeyen, test edilebilir mevcut sistem | 8-15 gün |
| 2 | Veri modeli, durum motoru ve yetki temeli | Tutarlı ve sunucuda korunan teklif yaşam döngüsü | 12-20 gün |
| 3 | Hızlı ve sade teklif hazırlama | Otomatik kaydeden, hızlı kullanılan teklif editörü | 15-25 gün |
| 4 | Maliyet, marj, onay, sürümleme ve PDF | Ticari olarak kontrollü, değişmez teklif sürümleri | 15-25 gün |
| 5 | Gerçek gönderim, müşteri portalı ve kabul | Kanıtlı gönderim, görüntüleme ve teklif kabulü | 25-40 gün |
| 6 | Fırsat, görev ve Cari 360 | Günlük satış ve müşteri takip sistemi | 25-40 gün |
| 7 | Raporlama, otomasyon, entegrasyon ve sertleştirme | Yönetim görünürlüğü ve sürdürülebilir canlı sistem | 20-30 gün |

### Zorunlu sıra

`Faz 1 -> Faz 2 -> Faz 3 -> Faz 4 -> Faz 5 -> Faz 6 -> Faz 7`

Tek kişi çalışırken fazlar paralel yürütülmemelidir. Bir fazın çıkış kriterleri tamamlanmadan bir sonraki büyük faza geçilmemelidir.

---

## 4. Yapay zekâ ile güvenli çalışma yöntemi

Bu bölüm bütün fazlarda uygulanmalıdır.

### 4.1 Her seferinde tek iş

Yapay zekâya şu tür istek verilmemelidir:

> Bütün teklif, CRM, portal ve cari sistemini profesyonel hale getir.

Bunun yerine tek, sınırları belli iş verilmelidir:

> Outlook taslağı açıldığında `email_sent_at` yazılmasını kaldır. Bunun yerine `email_draft_opened_at` kullanma seçeneğini analiz et, gerekli migration ve testleri ekle. Başka akışları değiştirme.

Bir iş ideal olarak 1-3 dosyalık değişiklik olmalıdır. Daha büyükse alt işlere ayrılmalıdır.

### 4.2 Her iş için kullanılacak yapay zekâ talimatı

Aşağıdaki şablon kullanılabilir:

```text
Bu projede yalnız [İŞİN ADI] üzerinde çalış.

Önce ilgili AGENTS.md talimatlarını ve mevcut kodu incele.
Mevcut kullanıcı değişikliklerini koru.
İşe başlamadan önce etkilenecek dosyaları ve veri modelini belirt.
Değişikliği küçük ve geri alınabilir şekilde yap.
Mevcut migration dosyasını değiştirme; yeni migration oluştur.
Yetki, hata durumu, boş durum ve eş zamanlılık etkilerini kontrol et.
Gerekli unit/widget/integration testlerini ekle veya güncelle.
İlgili testleri ve flutter analyze çalıştır.
Test geçmeden işi tamamlandı sayma.
İş sonunda değişen dosyaları, yapılanları, riskleri ve manuel kontrol adımlarını yaz.
Kapsam dışındaki kodu yeniden düzenleme.
```

### 4.3 Her işe başlamadan önce

1. `git status --short` ile mevcut değişiklikleri kontrol et.
2. Değişiklikleri yedekle veya anlamlı bir commit oluştur.
3. Supabase etkisi varsa veritabanı yedeği al.
4. Yapay zekâdan önce yalnız analiz ve küçük plan iste.
5. Plan kapsamı doğruysa uygulama izni ver.

### 4.4 Her iş bittikten sonra

1. Yapay zekânın söylediğine güvenip doğrudan canlıya alma.
2. `git diff` ile değişiklikleri incele.
3. İlgili testi çalıştır.
4. Uygulamayı elle açıp gerçek senaryoyu dene.
5. Supabase RLS değiştiyse farklı rollerle test et.
6. Sonuç doğruysa tek amaçlı commit oluştur.
7. Bir sonraki işe sonra geç.

### 4.5 Veritabanı için özel kurallar

- Uygulanmış eski migration dosyaları değiştirilmemeli.
- Her şema değişikliği yeni migration olmalı.
- Önce test/staging veritabanında uygulanmalı.
- Kolon silmek yerine önce yeni kolon eklenmeli ve veri taşınmalı.
- Backfill sonucunda kayıt sayıları kontrol edilmeli.
- RLS kapatılarak sorunu geçici çözme yoluna gidilmemeli.
- Service role anahtarı Flutter uygulamasına veya repoya konulmamalı.
- Canlı veritabanında doğrudan deneme SQL'i çalıştırılmamalı.

### 4.6 Bir iş ne zaman tamamlanmış sayılır?

- Kod derleniyor.
- İlgili testler geçiyor.
- Yeni analyzer hatası yok.
- Hatalı ve boş durumlar ele alındı.
- Yetkisiz kullanıcı senaryosu kontrol edildi.
- Veritabanı migration'ı tekrar çalıştırılabilir veya güvenli.
- Manuel kullanım senaryosu başarıyla tamamlandı.
- Geri alma yöntemi biliniyor.
- Yapılan değişiklik dokümante edildi.

---

## 5. Faz 1 - Güvenli başlangıç ve acil doğruluk düzeltmeleri

**Tahmini efor:** 8-15 net çalışma günü  
**Amaç:** Yeni özellik eklemeden önce mevcut sistemin yanlış bilgi üretmesini ve geri döndürülemez veri kaybını önlemek.

### Faz 1.1 Güvenli geliştirme tabanı

#### Yapılacaklar

- Mevcut çalışan sürümü etiketle veya commit ile sabitle.
- Supabase şema ve veri yedeği alma yöntemini doğrula.
- Test ve canlı ortam ayarlarını ayır.
- Gizli anahtarların repoda olmadığını kontrol et.
- Teklif uygulamasının ilgili testlerini tek komutla çalıştıran bir script oluştur.
- CI'ın `flutter analyze` ve bütün kritik testlerde başarısız olması sağlanmalı.

#### Kabul kriterleri

- Hatalı değişiklikten önceki çalışan sürüme dönülebiliyor.
- Test veritabanı canlı veriden bağımsız.
- Kritik test paketi yerelde ve CI'da aynı sonucu veriyor.

### Faz 1.2 E-posta gönderildi hatasını düzeltme

#### Mevcut hata

Outlook veya varsayılan e-posta istemcisinde yalnız taslak açılması, sistemde teklif gönderilmiş gibi `email_sent_at` alanına yazılıyor.

#### Yapılacaklar

- Taslak açılınca `markEmailSent` çağrısını kaldır.
- Kullanıcı mesajını "E-posta taslağı açıldı" olarak değiştir.
- Gerekirse ayrı `email_draft_opened_at` olayı tut.
- Geçici olarak kullanıcıya "Gönderildi olarak işaretle" seçeneği sun.
- Manuel işaretlemede kullanıcı, zaman, alıcı ve not sakla.
- Mevcut şüpheli gönderim kayıtlarını değiştirmeden önce yedekle ve işaretleme planı hazırla.

#### Testler

- Outlook taslağı açıldığında teklif `sent` olmuyor.
- Kullanıcı taslağı kapattığında gönderim metriği artmıyor.
- Manuel teyit doğru kullanıcı ve zamanla kaydoluyor.
- Hata halinde yanlış başarı mesajı çıkmıyor.

### Faz 1.3 Tamamlanmamış görüntülenme özelliğini güvenli hale getirme

#### Yapılacaklar

- Çalışan public portal doğrulanana kadar "görüntülendi" göstergesini gizle veya "doğrulanmadı" olarak göster.
- Bozuk `#/p/{token}` bağlantılarını müşteriye göndermeyi durdur.
- PDF içindeki QR/link gerçekten çalışmıyorsa geçici olarak kaldır.
- Dört karakterli yeni token üretimini durdur.
- Public portal Faz 5'te tamamlanana kadar müşteri erişimi varmış izlenimi verme.

#### Testler

- Portal yokken müşteriye bozuk link gönderilmiyor.
- Eski kayıtlardaki boş/eksik token uygulamayı çökertmiyor.
- Arayüz doğrulanmamış görüntülenmeyi kesin müşteri görüntülemesi olarak sunmuyor.

### Faz 1.4 Kalıcı silmeyi arşivlemeye çevirme

#### Yapılacaklar

- Cari silme işlemini `archived_at` veya `is_active=false` yap.
- Teklif silme yerine arşivle/geri al kullan.
- Bağlı teklifleri olan cariyi kalıcı silmeyi engelle.
- Arşiv filtresi ve geri yükleme ekle.

#### Testler

- Cari arşivlenince eski teklifler erişilebilir kalıyor.
- Arşivlenen cari yeni teklif seçiminde varsayılan görünmüyor.
- Yönetici cariyi geri yükleyebiliyor.

### Faz 1.5 Encoding ve kırık testler

#### Yapılacaklar

- Kaynak kodda görünen bozuk Türkçe karakterleri dosya dosya düzelt.
- Otomatik toplu değiştirme yapma; metinleri bağlamında kontrol et.
- `quote_editor_page_test.dart` içindeki `Bad state: No element` hatasını düzelt.
- Teklif, cari ve PDF testlerinin tamamını birlikte çalıştır.

#### Kabul kriterleri

- İlgili 15 testin 15'i geçiyor.
- Teklif ve cari ekranlarında gözle görülür bozuk Türkçe karakter kalmıyor.
- Faz 1 değişiklikleri mevcut teklif oluşturma/PDF akışını bozmuyor.

### Faz 1 çıkış kapısı

Aşağıdakiler tamamlanmadan Faz 2'ye geçme:

- E-posta taslağı artık gönderim sayılmıyor.
- Bozuk public link müşteriye gitmiyor.
- Cari ve teklifler yanlışlıkla kalıcı silinemiyor.
- İlgili bütün mevcut testler geçiyor.
- Canlıdan önce test ortamında manuel kontrol tamamlandı.

### Faz 1 sonunda yayınlanacak sürüm

**Sürüm A - Güvenli mevcut teklif aracı**

Bu sürüm yeni özellikli olmayabilir; ancak yanlış gönderim ve görüntülenme bilgisi üretmeyen, veri kaybı riski azaltılmış bir temel olur.

---

## 6. Faz 2 - Veri modeli, durum motoru ve yetki temeli

**Tahmini efor:** 12-20 net çalışma günü  
**Amaç:** Teklifin durumunu UI seçimlerinden değil, kontrollü iş kurallarından yöneten sağlam temel oluşturmak.

### Faz 2.1 Durum sözlüğünü düzeltme

#### Yeni teklif durumları

`draft -> approval_pending -> approved -> sent -> viewed -> negotiating -> won/lost/expired/cancelled`

#### Anlamları

| Durum | Anlam |
|---|---|
| `draft` | Satışçı düzenliyor |
| `approval_pending` | Şirket içi onay bekliyor |
| `approved` | Şirket içi onaylandı, gönderilebilir |
| `sent` | Gerçek gönderim başarıyla kaydedildi |
| `viewed` | Müşteri portalında doğrulanmış görüntüleme var |
| `negotiating` | Revizyon/pazarlık devam ediyor |
| `won` | Kanıtlı veya yetkili manuel kabul var |
| `lost` | Yapılandırılmış kayıp nedeni var |
| `expired` | Geçerlilik tarihi doldu |
| `cancelled` | Şirket tarafından iptal edildi |

### Faz 2.2 Teklif temel alanları

Yeni migration ile en az şu alanları ekle:

- `owner_user_id`,
- `valid_until`,
- `next_action_at`,
- `expected_close_at`,
- `loss_reason_code`,
- `status_changed_at`,
- `archived_at`.

Mümkünse `cari_id` ilişkisini güvenli foreign key yapısına taşı; önce eski kopuk kayıtları raporla.

### Faz 2.3 Sunucu tarafı durum komutları

Şu işlemler doğrudan `.update(status)` ile yapılmamalıdır:

- Onaya gönder,
- Onayla,
- Revizyon iste,
- Gönderildi yap,
- Pazarlığa al,
- Kazanıldı yap,
- Kaybedildi yap,
- İptal et,
- Arşivle.

Her işlem ayrı RPC veya tek güvenli `transition_quote_status` RPC üzerinden yürütülmelidir.

RPC şunları kontrol etmelidir:

- Mevcut durum,
- Hedef durum,
- Kullanıcı rolü,
- Teklif sahipliği,
- Zorunlu alanlar,
- Kayıp/iptal gerekçesi,
- Onay veya müşteri kanıtı,
- Aynı işlemin tekrar çağrılması.

### Faz 2.4 Rol ve alan yetkileri

Minimum roller:

- Satışçı,
- Satış yöneticisi,
- Finans/fiyat onaylayıcı,
- Sistem yöneticisi,
- Salt okunur kullanıcı.

Paylaşılan kullanıcının bütün teklifi değiştirmesi yerine görüntüleme, yorum, düzenleme ve onay yetkileri ayrılmalıdır.

### Faz 2.5 Tarih ve takip alanları

- `validityText` korunabilir; gerçek kontrol `valid_until` ile yapılmalı.
- Kayıp nedeni serbest not yanında seçimli kod olmalı.
- Açık tekliflerde sonraki aksiyon tarihi gösterilmeli.
- Geçerliliği dolan teklifler otomatik veya kontrollü `expired` olmalı.

### Faz 2 testleri

- Satışçı kendi taslağını düzenleyebiliyor.
- Satışçı şirket içi onay veremiyor.
- Onaysız teklif `sent` olamıyor.
- `won` için kabul kaydı veya yetkili manuel işlem gerekiyor.
- `lost` için neden zorunlu.
- Geçersiz durum atlaması backend tarafından reddediliyor.
- Aynı komut iki kez çağrıldığında çift olay oluşmuyor.
- RLS farklı rollerle test ediliyor.

### Faz 2 çıkış kapısı

- UI dışında doğrudan durum değiştirmek mümkün değil.
- Durum adları kullanıcıya ve veritabanına aynı anlamı ifade ediyor.
- Açık tekliflerin sahibi ve geçerlilik tarihi var.
- Eski kayıtlar yeni duruma kayıpsız taşındı.
- Migration hem boş test DB'de hem veri kopyasında çalıştı.

---

## 7. Faz 3 - Hızlı ve sade teklif hazırlama

**Tahmini efor:** 15-25 net çalışma günü  
**Amaç:** Satış personelinin programı tercih etmesini sağlayacak en görünür iyileştirmeyi yapmak.

Bu faz tek seferde 5.500 satırlık editörü yeniden yazma işi değildir. Ekran küçük parçalara ayrılarak adım adım değiştirilmelidir.

### Faz 3.1 Editörü bileşenlere ayırma

Önce davranışı değiştirmeden şu bölümleri ayrı widget/controller/service dosyalarına taşı:

- Müşteri ve teklif bilgisi,
- Ürün seçici,
- Kalem tablosu,
- Ticari koşullar,
- Fiyat özeti,
- Gizli maliyetler,
- Çıktı ve kayıt işlemleri.

Her taşıma sonrasında test çalıştır. Bütün dosyayı yapay zekâya tek seferde parçalatma.

### Faz 3.2 Üç aşamalı kullanıcı akışı

1. **Müşteri ve konu**
2. **Kalemler ve fiyat**
3. **Koşullar, ön izleme ve kayıt**

Standart kullanıcıya yalnız gerekli alanlar gösterilmeli. Şirket/banka ayarları ve gelişmiş maliyet araçları varsayılan olarak kapalı olmalıdır.

### Faz 3.3 Otomatik taslak

#### Yapılacaklar

- Değişiklikten 10-15 saniye sonra otomatik kaydet.
- Aynı anda birden fazla save çağrısını sırala.
- `Kaydediliyor`, `Kaydedildi`, `Çevrimdışı`, `Çakışma` durumlarını göster.
- Yerel kurtarma kopyası oluştur.
- Ekrandan çıkarken kaydedilmemiş değişikliği uyar.
- Sunucu çakışmasında veriyi sessizce ezme.

#### Testler

- Yazı yazarken her tuşta ayrı kayıt oluşmuyor.
- Ağ kesilince kullanıcı girdisi kaybolmuyor.
- Tekrar bağlanınca güvenli senkronizasyon oluyor.
- İki cihaz aynı teklifi değiştirirse kullanıcı bilgilendiriliyor.

### Faz 3.4 Hızlı kalem tablosu

Öncelik sırası:

1. Ürün kodu/adı ile hızlı arama,
2. Enter/Tab ile hücre geçişi,
3. Satır ekleme, çoğaltma ve silme,
4. Çoklu ürün seçimi,
5. Toplu kategori ve iskonto,
6. Excel'den satır yapıştırma,
7. Geri al/yinele,
8. Opsiyonel/alternatif kalem.

Her özellik ayrı iş olarak uygulanmalıdır.

### Faz 3.5 Şablonlar ve hızlı başlangıç

Yeni teklif açarken:

- Boş teklif,
- Hazır ürün paketinden,
- Önceki tekliften,
- Keşif/projeden

seçenekleri sunulmalıdır.

İlk sürümde şunlar yeterlidir:

- Favori ürünler,
- Son kullanılan ürünler,
- Cari geçmişinde kullanılan ürünler,
- Tek tık ürün/hizmet paketi,
- Standart ödeme/teslim/geçerlilik şablonu.

### Faz 3.6 Güvenli kopyalama

Kopyalarken kullanıcı seçmelidir:

- Güncel veya eski fiyat,
- Güncel veya eski kur,
- Cari ve yetkiliyi taşıma,
- Ticari koşulları taşıma,
- Notları taşıma.

Eski fiyat veya kur kullanılırsa belirgin uyarı gösterilmelidir.

### Faz 3.7 Ana aksiyonları sadeleştirme

Ana aksiyonlar:

- Taslak kaydet,
- Ön izleme,
- Onaya gönder.

Malzeme istek PDF/Excel ve operasyon çıktıları ikincil menüye veya operasyon modülüne taşınmalıdır.

### Faz 3 testleri

- Yeni, kopya ve revizyon modları,
- 1, 10, 100 ve 500 kalemli teklifler,
- Klavye ile veri girişi,
- Dar ekran ve masaüstü,
- Otomatik taslak ve kurtarma,
- Kur ve fiyat kopyalama seçenekleri,
- Uzun Türkçe açıklamalar,
- Toplam/iskonto hesapları.

### Faz 3 çıkış kapısı

- Standart 10 kalemli teklif 3-5 dakika içinde hazırlanabiliyor.
- Kullanıcı pencere kapanmasında taslağını kaybetmiyor.
- Teklif yalnız klavyeyle düzenlenebiliyor.
- Kopyalamada hangi fiyat/kurun kullanıldığı açık.
- Dar ekranda taşma yok.
- Bütün eski teklif ve PDF testleri geçiyor.

### Faz 3 sonunda yayınlanacak sürüm

**Sürüm B - Hızlı teklif hazırlama aracı**

Bu noktada satış ekibinin günlük teklif üretiminde sistemi tercih etmesi hedeflenir. CRM veya müşteri portalı tamamlanmamış olsa da teklif hazırlama süreci belirgin şekilde iyileşmiş olur.

---

## 8. Faz 4 - Maliyet, marj, onay, sürümleme ve PDF

**Tahmini efor:** 15-25 net çalışma günü  
**Amaç:** Teklif fiyatının ticari olarak kontrol edilmesini ve müşteriye gönderilen her sürümün değişmez kalmasını sağlamak.

### Faz 4.1 Maliyet ve marj modeli

Her satırda ayrı tutulması gerekenler:

- Standart veya son alış maliyeti,
- Maliyet para birimi,
- Maliyet kuru ve tarihi,
- Lojistik/işçilik/genel gider,
- Liste satış fiyatı,
- İskonto,
- Net satış fiyatı,
- Marj tutarı,
- Marj oranı.

`HiddenCostItem` korunabilir; ancak gerçek maliyet ve marjın yerine kullanılmamalıdır.

### Faz 4.2 İç fiyat özeti

Satışçı ve yönetici için:

- Toplam maliyet,
- Net satış,
- Brüt kâr,
- Marj yüzdesi,
- İskonto etkisi,
- Kur riski,
- Onay gerektiren satırlar

gösterilmelidir. Bu bilgiler müşteri PDF'ine girmemelidir.

### Faz 4.3 Fiyat ve onay kuralları

İlk sürümde karmaşık kural motoru yerine basit ayarlar yeterlidir:

- Satışçı maksimum iskonto oranı,
- Minimum toplam marj,
- Belirli tutar üstü yönetici onayı,
- Özel fiyat değişikliğinde açıklama,
- Süresi geçmiş kurda uyarı.

Kurallar veritabanında tutulmalı; Flutter içine sabit yazılmamalıdır.

### Faz 4.4 Onay akışı

- Onaya gönder,
- Yönetici onayla,
- Revizyon iste,
- Reddet.

Onay ekranında önceki ve yeni fiyatlar, iskonto ve marj farkı gösterilmelidir. Onay sonrası yayımlanacak sürümün ticari alanları kilitlenmelidir.

### Faz 4.5 Değişmez teklif sürümü

Yeni `quote_versions` kaydı:

- `quote_id`,
- `version_no`,
- Tam teklif snapshot'ı,
- Kalemler ve ticari koşullar,
- Oluşturan/onaylayan,
- `valid_until`,
- PDF storage yolu,
- PDF SHA-256 hash'i,
- Yayımlanma ve geri çekilme zamanı.

Gönderim ve müşteri kabulü ileride `quote_id` yerine bu sürüme bağlanacaktır.

### Faz 4.6 PDF iyileştirmesi

- Her sayfada teklif no ve revizyon,
- Kesin geçerlilik tarihi,
- Kapsam ve kapsam dışı işler,
- Alternatif/opsiyonel kalemler,
- Güncel/eski sürüm işareti,
- İç maliyet belgesi ile müşteri teklifinin kesin ayrımı,
- PDF hash doğrulama bilgisi,
- Uzun metin ve çok sayfalı görsel test.

### Faz 4 testleri

- Marj ve KDV hassasiyeti,
- Farklı para birimleri,
- İskonto sınırları,
- Yetkisiz onay,
- Onay sonrası değişmezlik,
- Aynı sürümün aynı iş verisini temsil etmesi,
- İç maliyetin müşteri PDF'ine girmemesi,
- Eski sürümün güncel gibi yayımlanamaması.

### Faz 4 çıkış kapısı

- Düşük marjlı teklif yetkisiz yayımlanamıyor.
- Her müşteri teklifi değişmez bir sürüme sahip.
- PDF hash'i ve sürümü doğrulanabiliyor.
- Onay geçmişi kaybolmuyor.
- Müşteri PDF'inde hiçbir iç maliyet alanı yok.

---

## 9. Faz 5 - Gerçek gönderim, müşteri portalı ve kabul

**Tahmini efor:** 25-40 net çalışma günü  
**Amaç:** Teklifin gerçekten gönderildiğini, müşterinin hangi sürümü görüntülediğini ve neyi kabul ettiğini kanıtlamak.

Bu faz dış servis ve güvenlik içerdiği için en riskli fazdır. Alt işleri tek tek bitirerek ilerlemek gerekir.

### Faz 5 başlamadan verilmesi gereken kararlar

Ayrı keşif fazı yapılmayacak; ancak uygulama öncesinde şu üç zorunlu seçim yapılmalıdır:

1. Hangi kurumsal e-posta sağlayıcısı kullanılacak?
2. Müşteri portalının kesin domaini ne olacak?
3. Müşteri kabulünde e-posta linki mi, OTP mi kullanılacak?

Bu kararlar verilmeden yapay zekâdan entegrasyon kodu istenmemelidir.

### Faz 5.1 Gönderim veri modeli

`quote_deliveries`:

- Gönderilen teklif sürümü,
- Kanal,
- Alıcı ve CC,
- Konu/metin snapshot'ı,
- Sağlayıcı mesaj kimliği,
- `queued/sent/delivered/bounced/failed`,
- İşlemi yapan,
- Zamanlar.

`quote_events`:

- `email_opened`,
- `link_clicked`,
- `portal_viewed`,
- `pdf_downloaded`,
- `question_submitted`,
- `revision_requested`,
- `accepted/rejected`.

### Faz 5.2 Sunucu e-posta gönderimi

- E-posta Flutter istemcisinden değil güvenli backend/Edge Function üzerinden gönderilmeli.
- Service/API anahtarı uygulamada bulunmamalı.
- Her çağrıda idempotency key kullanılmalı.
- Başarı yalnız sağlayıcı mesajı kabul ettiğinde kaydedilmeli.
- Teslim, bounce ve hata webhook ile güncellenmeli.
- Retry işlemi çift e-posta üretmemeli.

İlk sürümde e-posta açılma pikseli yapılmayabilir. Teslim ve portal görüntülemesi daha güvenilir ölçülerdir.

### Faz 5.3 Güvenli public token

- En az 128 bit rastgele token,
- Veritabanında mümkünse yalnız hash,
- Benzersiz indeks,
- Son kullanma zamanı,
- İptal/yenileme,
- Rate limit,
- Erişim logu,
- Yalnız tek teklif sürümüne erişim.

### Faz 5.4 Müşteri portalı

İlk sürümün kapsamı küçük tutulmalıdır:

- Teklif özeti,
- Kalem ve toplamlar,
- Ticari koşullar,
- PDF indirme,
- Güncel/süresi dolmuş/geri çekilmiş sürüm mesajı,
- Kabul et,
- Reddet veya revizyon iste.

İlk sürümde sohbet, ödeme, gelişmiş müşteri hesabı gibi özellikler eklenmemelidir.

### Faz 5.5 Dijital kabul

Kaydedilecek kanıt:

- Teklif sürümü,
- Cari ve yetkili,
- Doğrulanan e-posta/telefon,
- Kabul zamanı,
- IP ve user-agent,
- Teklif toplamı ve para birimi,
- Kabul metni sürümü,
- OTP/doğrulama sonucu,
- Kabul kanıtı PDF'i.

Hukuki kabul metni yapay zekâya bırakılmamalı; şirketin hukuk/mali müşaviri tarafından onaylanmalıdır.

### Faz 5.6 Tekliften iş emri oluşturma

Kabul sonrasında tek transaction/RPC:

1. Kabul kaydını doğrula.
2. Teklif sürümünü kilitle.
3. Tek bir iş emri oluştur.
4. Kapsam kalemlerini aktar.
5. Teklif ve iş emrini karşılıklı bağla.
6. Satış ve operasyon bildirimini oluştur.

Tekrar tıklama veya webhook tekrarında ikinci iş emri oluşmamalıdır.

### Faz 5 güvenlik testleri

- Rastgele/bozuk token,
- Süresi dolmuş token,
- Geri çekilmiş sürüm,
- Token brute force/rate limit,
- Başka teklif sürümüne erişim,
- Tekrarlı gönderim,
- Sahte webhook,
- Tekrarlı kabul,
- Değiştirilmiş toplamla kabul isteği,
- Yetkisiz iş emri oluşturma.

### Faz 5 çıkış kapısı

- Gönderim sağlayıcı kabul etmeden `sent` oluşmuyor.
- Her gönderim tek teklif sürümüne bağlı.
- Portal yalnız izin verilen sürümü gösteriyor.
- Kabul kaydı kişi, sürüm, toplam ve koşulları kanıtlıyor.
- Aynı kabul yalnız bir iş emri oluşturuyor.
- Kritik/yüksek güvenlik açığı yok.
- En az 10 test teklifi uçtan uca sorunsuz işlendi.

### Faz 5 sonunda yayınlanacak sürüm

**Sürüm C - Profesyonel teklif ve satış MVP'si**

Bu sürümden sonra teklif hazırlama, onay, gönderim, müşteri görüntüleme/kabul ve iş emri başlangıcı tek zincir halinde çalışır.

---

## 10. Faz 6 - Fırsat, görev ve Cari 360

**Tahmini efor:** 25-40 net çalışma günü  
**Amaç:** Teklif uygulamasını satışçının günlük müşteri ve fırsat takip aracına dönüştürmek.

Faz 5 sahada kararlı çalışmadan Faz 6'ya geçilmemelidir.

### Faz 6.1 Cari veri modelini düzeltme

Mevcut `contacts jsonb` yerine zaman içinde şu tablolar eklenmelidir:

- `accounts`,
- `account_contacts`,
- `account_addresses`,
- `account_tags`,
- `account_assignments`.

Tek seferde eski alanları silme. Önce yeni tabloları ekle, backfill yap, doğrula, uygulamayı yeni okumaya geçir, sonra eski alanları kullanım dışı bırak.

### Faz 6.2 Mükerrer cari kontrolü

- Vergi numarası koşullu benzersizliği,
- Normalize firma adı,
- Telefon/e-posta benzerlik uyarısı,
- Olası mükerrer listesi,
- Yönetici birleştirme işlemi,
- Birleştirme audit'i.

Birleştirme; teklif, kişi, aktivite ve iş emri bağlantılarını korumalıdır.

### Faz 6.3 Fırsat modeli

`opportunities` için ilk sürüm alanları:

- Fırsat adı,
- Cari,
- Ana yetkili,
- Satış sahibi,
- Aşama,
- Tahmini tutar,
- Olasılık,
- Beklenen kapanış,
- Sonraki aksiyon,
- Kaynak,
- Kayıp nedeni,
- Bağlı teklifler.

İlk pipeline:

`lead -> qualified -> discovery -> proposal -> negotiation -> won/lost`

### Faz 6.4 Aktivite ve görevler

Aktivite türleri:

- Arama,
- E-posta,
- WhatsApp,
- Toplantı,
- Not,
- Teklif olayı,
- Sistem olayı.

Görev alanları:

- Sorumlu,
- Son tarih,
- Öncelik,
- Fırsat/cari bağlantısı,
- Hatırlatma,
- Tamamlanma.

### Faz 6.5 Satışçı çalışma masası

Öncelikle şu listeler yeterlidir:

- Bugünkü görevler,
- Geciken görevler,
- Onay bekleyen teklifler,
- Gönderilip cevap bekleyenler,
- Süresi dolacak teklifler,
- Sonraki aksiyonu olmayan fırsatlar.

Grafiklerden önce eylem listeleri yapılmalıdır.

### Faz 6.6 Cari 360

- Firma özeti,
- Yetkililer ve adresler,
- Aktiviteler,
- Görevler,
- Fırsatlar,
- Teklifler ve sürümler,
- Kazanılan işler,
- Servis geçmişi,
- Belgeler.

Finansal bakiye Faz 7 entegrasyonuna kadar boş/entegrasyon bekliyor olarak kalabilir.

### Faz 6 testleri

- Cari oluşturma/düzenleme/arşivleme,
- Mükerrer tespiti,
- Cari birleştirme,
- Yetkili taşıma,
- Fırsat durum geçişleri,
- Görev gecikme hesapları,
- Yetkisiz cari/fırsat erişimi,
- 10 bin cari/50 bin teklif sayfalama testi.

### Faz 6 çıkış kapısı

- Tekliflerin en az %95'i cari ve yetkiliye bağlı.
- Açık fırsatların en az %90'ında sonraki aksiyon var.
- Cari birleştirmede bağlantı kaybı oluşmuyor.
- Satışçı günlük takip için ayrı Excel listesine ihtiyaç duymuyor.
- Cari ve teklif listeleri sunucu tarafı sayfalama kullanıyor.

---

## 11. Faz 7 - Raporlama, otomasyon, entegrasyon ve sertleştirme

**Tahmini efor:** 20-30 net çalışma günü  
**Amaç:** Yönetim raporlarını güvenilir hale getirmek, tekrar eden takipleri otomatikleştirmek ve sistemi diğer şirket yazılımlarına bağlamak.

Bu fazın alt parçaları ihtiyaç varsa ayrı projeler halinde yapılabilir. Hepsini aynı anda yapmaya çalışma.

### Faz 7.1 Güvenilir KPI veri katmanı

Raporlar istemcide bütün teklifleri çekip toplamamalıdır. SQL view/materialized view veya güvenli rapor fonksiyonları kullanılmalıdır.

İlk KPI'lar:

- Teklif adedi ve tutarı,
- Kazanma oranı,
- Açık pipeline,
- Ortalama iskonto,
- Ortalama marj,
- Onay bekleme süresi,
- Tekliften sonuca satış döngüsü,
- Kayıp nedenleri,
- Satışçı performansı.

### Faz 7.2 Takip otomasyonları

İlk sürüm yalnız satışçıya görev/bildirim üretmelidir:

- Gönderildi ama portalda görüntülenmedi,
- Görüntülendi ama cevap yok,
- Geçerlilik yaklaşıyor,
- Teklif süresi doldu,
- Onay süresi aşıldı,
- Fırsatta sonraki aksiyon yok.

Müşteriye otomatik mesaj göndermek daha sonra ve ayrı onayla yapılmalıdır.

### Faz 7.3 Finansal cari/ERP entegrasyonu

Önce kaynak sistem kararı verilmelidir:

- Cari kod,
- Bakiye,
- Risk limiti,
- Açık faturalar,
- Tahsilatlar,
- Ürün maliyetleri

hangi sistemde ana veri olacak?

Teklif uygulamasında çift muhasebe sistemi geliştirmek yerine mevcut ERP/muhasebe sisteminden özet alınması önerilir.

### Faz 7.4 Takvim ve iletişim entegrasyonu

İhtiyaca göre sıralı ilerle:

1. Takvim görevi/toplantı,
2. Kurumsal e-posta,
3. WhatsApp Business API.

Her entegrasyon ayrı kimlik doğrulama, hata kuyruğu, retry ve audit gerektirir.

### Faz 7.5 Güvenlik ve operasyon

- RLS rol testleri,
- Public portal rate limit,
- Token ve OTP brute force koruması,
- Hassas log temizliği,
- Yük testi,
- Yedekleme ve geri yükleme tatbikatı,
- Hata izleme,
- Audit saklama politikası,
- Bağımlılık güncelleme planı.

### Faz 7.6 Kullanıcıya yaygınlaştırma

- Önce kendi test hesabın,
- Sonra 1 satışçı,
- Sonra 2-3 kişilik pilot,
- Sonra bütün satış ekibi.

Her geçişte gerçek teklif sayısı, hata ve geri dönüş oranı izlenmelidir. Eski Word/Excel yöntemi hemen silinmemeli; kısa bir geçişten sonra salt okunur arşiv yapılmalıdır.

### Faz 7 çıkış kapısı

- Dashboard sayıları örnek ham kayıtlarla tutarlı.
- Entegrasyon hataları görünür ve tekrar işlenebilir.
- Finansal veri kaynağı tek ve belgelenmiş.
- Kritik/yüksek güvenlik açığı yok.
- Yedekten geri dönüş denendi.
- Satış ekibi temel görevleri eğitim almadan veya kısa rehberle yapabiliyor.

---

## 12. Tek kişi için önerilen küçük iş sırası

Bu liste ilk aşamada doğrudan kullanılabilecek backlog sırasıdır. Her madde ayrı yapay zekâ oturumu ve ayrı commit olmalıdır.

### İlk 20 iş

1. `SAFE-001` Mevcut test komutlarını ve sonuçlarını dokümante et.
2. `SAFE-002` Teklif editörü kırık widget testini düzelt.
3. `MAIL-001` Outlook taslağında `markEmailSent` çağrısını kaldır.
4. `MAIL-002` Mailto açılışında `markEmailSent` çağrısını kaldır.
5. `MAIL-003` Başarı mesajlarını "taslak açıldı" olarak düzelt.
6. `PUBLIC-001` Portal yokken WhatsApp/public link gönderimini kapat.
7. `PUBLIC-002` Doğrulanmamış görüntülenme göstergesini gizle.
8. `DATA-001` Cari için arşiv alanı migration'ı oluştur.
9. `CARI-001` Cari silmeyi arşivlemeye çevir.
10. `DATA-002` Teklif kalıcı silmeyi arşivlemeye çevir.
11. `TEXT-001` Teklif ekranındaki bozuk Türkçe metinleri düzelt.
12. `TEXT-002` Cari ekranındaki bozuk Türkçe metinleri düzelt.
13. `STATE-001` Yeni durum sözlüğünü model ve migration olarak ekle.
14. `STATE-002` Durum geçiş matrisini unit testlerle oluştur.
15. `STATE-003` Sunucu tarafı durum RPC'sini oluştur.
16. `STATE-004` UI durum işlemlerini RPC'ye bağla.
17. `QUOTE-001` `valid_until` alanını ekle.
18. `QUOTE-002` `owner_user_id` ve `next_action_at` alanlarını ekle.
19. `QUOTE-003` Kayıp nedenini seçimli hale getir.
20. `EDITOR-001` Teklif editörünün müşteri bilgi bölümünü ayrı widget'a taşı.

### Sonraki editör işleri

21. Kalem tablosunu ayrı widget/controller yap.
22. Ticari koşulları ayrı bileşen yap.
23. Fiyat özetini ayrı bileşen yap.
24. Otomatik taslak durum modelini oluştur.
25. Debounce ile taslak kayıt ekle.
26. Yerel kurtarma ekle.
27. Kaydedilmemiş değişiklik uyarısı ekle.
28. Klavye hücre geçişlerini ekle.
29. Çoklu ürün seçimi ekle.
30. Favoriler ve son kullanılanları ekle.
31. Ürün paketi modelini ekle.
32. Kopyalamada fiyat/kur seçim ekranını ekle.

Bu sıra bitmeden müşteri portalına başlanmaması önerilir.

---

## 13. Her fazda çalıştırılacak kontroller

### Kod kontrolü

```powershell
git status --short
git diff --check
flutter analyze
flutter test
```

Projenin kök uygulaması ve `uzalteklif` ayrı Flutter uygulamaları olduğu için komutlar doğru klasörde ayrı ayrı çalıştırılmalıdır.

### Manuel kontrol listesi

- Yeni teklif oluştur,
- Taslak kaydet ve yeniden aç,
- Teklif kopyala,
- Revizyon oluştur,
- Onaya gönder,
- Yetkisiz kullanıcıyla onay dene,
- PDF üret,
- Cari oluştur/düzenle/arşivle,
- Dar ekranı kontrol et,
- İnternet kesintisi/hata mesajını kontrol et.

### Supabase kontrol listesi

- Migration test ortamında uygulandı mı?
- Veri sayıları migration öncesi/sonrası aynı mı?
- RLS açık mı?
- Anon kullanıcı gereğinden fazla veri görüyor mu?
- Satışçı başka kullanıcının teklifini değiştirebiliyor mu?
- Audit kaydı oluşuyor mu?
- İşlem tekrar çağrıldığında çift kayıt oluşuyor mu?

---

## 14. Yapay zekâya bırakılmaması gereken kararlar

Yapay zekâ seçenek hazırlayabilir; aşağıdaki kararları sizin veya ilgili uzmanların vermesi gerekir:

- Minimum marj ve iskonto yetkileri,
- Kimlerin teklif onaylayacağı,
- Müşteri kabul metninin hukuki içeriği,
- KVKK ve izleme politikası,
- Kur ve fiyatın hangi kaynaktan geleceği,
- Finansal carinin ana sistemi,
- E-posta/WhatsApp sağlayıcısı ve maliyeti,
- Verilerin ne kadar süre saklanacağı,
- Canlı migration ve veri silme onayı.

Bu kararlar ilgili faz başladığında verilmelidir; ayrı bir keşif fazı yapılmasına gerek yoktur.

---

## 15. Kaçınılması gereken çalışma biçimleri

- Yapay zekâya bütün projeyi tek seferde yeniden yazdırmak,
- Test geçmeden sonraki özelliğe geçmek,
- Canlı veritabanında deneme migration'ı çalıştırmak,
- Eski migration dosyalarını değiştirmek,
- RLS sorununu RLS'i kapatarak çözmek,
- Service role anahtarını Flutter koduna koymak,
- Büyük ekran dosyasını testsiz parçalara ayırmak,
- Aynı anda editör, portal, CRM ve ERP geliştirmek,
- Gönderim sağlayıcı sonucu olmadan `sent` yazmak,
- Yapay zekâ çıktısını kod incelemeden canlıya almak,
- Geri dönüş planı olmadan veri dönüştürmek,
- Görsel iyileştirmeyi veri doğruluğunun önüne almak.

---

## 16. Başarı ölçütleri

### Faz 1 sonrası

- Yanlış gönderim kaydı oluşmuyor.
- Bozuk public bağlantı müşteriye gitmiyor.
- Kalıcı cari/teklif kaybı önlendi.
- Kritik testlerin tamamı geçiyor.

### Faz 3 sonrası

- Standart teklif 3-5 dakikada hazırlanıyor.
- Taslak veri kaybı yaşanmıyor.
- Kopya teklif eski fiyat/kur riskini açıkça gösteriyor.
- Satışçı temel akışı dış Excel/Word olmadan yapabiliyor.

### Faz 5 sonrası

- Gönderimlerin tamamı belirli teklif sürümüne bağlı.
- `sent` yalnız doğrulanmış gönderimde oluşuyor.
- Müşteri yalnız güncel ve izinli sürümü görüyor.
- Kabul kaydı kişi, sürüm, tutar ve koşulları kanıtlıyor.
- Kabul ikinci iş emri oluşturmuyor.

### Faz 6-7 sonrası

- Tekliflerin en az %95'i cari ve yetkiliye bağlı.
- Açık fırsatların en az %90'ında sonraki aksiyon var.
- Kayıp tekliflerin en az %95'inde neden var.
- Manuel Excel/Word kullanımında en az %80 azalma var.
- Yönetim raporları ham verilerle mutabık.

---

## 17. Sonuç ve önerilen başlangıç

Tek kişi ve yapay zekâ desteğiyle bu sistem yapılabilir; ancak başarı için kapsamı küçük tutmak ve her değişikliği doğrulamak gerekir. İlk hedef CRM veya müşteri portalı değildir. İlk hedef mevcut teklif uygulamasının güvenilir olmasıdır.

Önerilen çalışma sırası:

`Yanlış gönderim kaydını düzelt -> bozuk public özellikleri kapat -> silmeyi güvenli yap -> testleri düzelt -> durum motorunu kur -> editörü hızlandır -> marj/onay/sürümleme -> gerçek gönderim ve portal -> CRM -> raporlama/entegrasyon`

İlk uygulanacak teknik iş:

> Outlook ve mailto taslağı açıldığında teklifin gönderilmiş sayılmasını kaldırmak ve bunu otomatik testle güvenceye almak.

Bu iş küçük, mevcut riski yüksek ve doğrulanması kolay olduğu için yapay zekâ destekli geliştirmeye en uygun başlangıç noktasıdır.

