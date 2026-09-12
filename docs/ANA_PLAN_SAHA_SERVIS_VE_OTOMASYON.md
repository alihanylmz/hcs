# Ana Plan — Saha/Servis Akışı, Otomasyon Sözleşmeleri ve Fazlar

**Not:** Bu dosya, `TEKLIF_SATIS_CARI_SISTEMI_PROFESYONELLESTIRME_RAPORU.md` raporunun
parçası değildir; kullanıcının elindeki daha genis "ana plan" belgesinden
sohbete yapıştırılan iki parçanın olduğu gibi kaydıdır. Sıralama, yapıştırılma
sırasına göredir; belgenin orijinal bölüm numaralandırmasıyla (6-12 ve F7-F11)
tam örtüşmeyebilir, bu yüzden içerik yeniden düzenlenmeden aktarılmıştır.

---

## Bölüm 1 — Fazlar (F7-F11) ve teslim büyüklükleri

### F7-02 — Servis detay raporu

- İş: Talep, bulgu, yapılan işlem, cihaz ölçümleri/birimleri, kullanılan malzemeler, çalışma süresi, fotoğraf, sonuç ve açık eksikleri alanlaştır. Çok günlük işte günlük kayıtları son rapora bağla.
- Kabul: Zorunlu alanlar olmadan incelemeye gönderilemez. Malzeme sarfı aynı kaynak işlemiyle tekrar düşmez. Her eksik işin sahibi ve tarihi vardır.
- Test: Eksik ölçüm birimi, negatif süre/miktar, fotoğraf yüklenememesi, tekrarlanan malzeme senkronizasyonu.

### F7-03 — Rapor inceleme ve müşteri teyidi

- İş: Koordinatör onay/iade, teknisyen düzeltme ve müşteri teyit durumlarını ayır. İmzalı/onaylı sürümü kilitle. Yeni rapor sürümünün öncekini nasıl düzelttiğini göster.
- Kabul: Rapor iade edilince gerekçe teknisyene görev olur. Müşteri imzası yoksa "müşteri kabul etti" yazılmaz. Onaylı rapor içeriği değiştirilemez.
- Test: Kendi kendine uygunsuz onay, eski sürüme imza, imza reddi, onay sonrası düzenleme.

### F7-04 — Bağlantı kesintisi ve tekrar ziyaret

- İş: Yerel taslakların durumunu, kaydedilmemiş fotoğrafları ve tekrar gönderim anahtarlarını yönet. Çakışmada birleştirme/yeniden yükleme seçeneği ver. Tamamlanamayan işten aynı talebe bağlı yeni ziyaret oluştur.
- Kabul: Bağlantı gelince bir rapor iki kez oluşmaz. Sunucu onayı alınmamış müşteri imzası kesinleşmiş görünmez. İkinci ziyaret ilk raporu silmez.
- Test: Uygulama kapanıp açılması, fotoğrafın yarıda kalması, başka cihazdaki güncelleme, tekrar ziyaretin yanlış talebe bağlanması.
- Sınır: Tam çevrimdışı veri tabanı replikasyonu yazılmaz; pilot için belirlenen taslak kapsamı uygulanır.

Faz çıkışı: En az bir ziyaret, onaylı detay raporu, doğru malzeme/süre ve açık eksik listesi uçtan uca çalışır.

## F8 — Devreye alma ve müşteri kabulü

Amaç: Formu oluşturmanın ötesinde devreye almanın tamamlandığını kanıtlamak.

Ön koşul: F7 ve teknik şablon kararı D07.

### F8-01 — Otomatik devreye alma dosyası

- İş: A05'i uygula. Rapor onayı sonrası ilgili kapsam/cihazlar ve şablon sürümüyle tek taslak oluştur. Birden çok ziyaret/raporun gerekliliklerini açık ilişkiyle tut.
- Kabul: Aynı rapor olayı tekrar geldiğinde yeni dosya oluşmaz. Eksik zorunlu raporlar dosyayı hazır yapmaz. İlgisiz cihaz bu forma eklenmez.
- Test: Çok ziyaret, kısmi hazır paket, tekrar olay, eksik şablon.

### F8-02 — Cihaz kontrolleri ve sonuçları

- İş: D07 onaylı maddeleri birim, beklenen kriter, gerçekleşen değer, sonuç ve kanıtıyla kaydet. Uygulanamaz cevabı varsa gerekçe ve yetki iste.
- Kabul: Bütün maddeler varsayılan başarılı gelmez. Başarısız engelleyici madde kabulü durdurur. Kontrolün kim/tarih/sürüm bilgisi vardır.
- Test: Aralık dışı ölçüm, boş zorunlu test, uygulanamaz kötüye kullanımı, farklı cihaz şablonu.

### F8-03 — Eksik işler ve kabul kararı

- İş: Kabul/koşullu kabul/düzeltme gerek durumlarını uygula. Eksiklerin sorumlu/tarihini, müşteri kararını ve belge sürümünü bağla.
- Kabul: Engelleyici eksik varken tam kabul olmaz. Koşullu kabulde iş tam kapanmış gösterilmez. Düzeltmenin kapanması doğrulayanla kayıtlıdır.
- Test: Müşteri imza vermemesi, açık engelleyici, tekrar test, eksik kapatma yetkisi.

### F8-04 — Ana iş kapanış kontrolü

- İş: Paket/ziyaret/rapor/devreye alma/belge/eksik kontrolünü tek sunucu komutunda yap. Önce operasyonu tamamla, zorunlu belge üretimi başarılı olunca dosyayı kapat. Yeniden açma gerekçeli ve yetkili olsun.
- Kabul: Tek paket bitişi tüm projeyi kapatmaz. Cari ve satış projesinde iş sonucu güncellenir. Eksik belge varsa nedeni ve sorumlusu görünür.
- Test: Açık ikinci paket, PDF hatası, başka kullanıcıyla eşzamanlı kapanış, izsiz yeniden açma denemesi.

Faz çıkışı/demo: Tekliften başlayan iş gerçek kontrol kayıtları ve müşteri kabulüyle kapanır; ikinci ziyaret ve düzeltme geçmişi kaybolmaz.

## F9 — Belge dosyası ve müşteri geri bildirim döngüsü

Amaç: Bütün belgeleri ve müşteri iletişimini iş geçmişinde tamamlamak.

Ön koşul: F8; temel belge altyapısı F1'den beri kullanılır.

### F9-01 — İş belge dosyası

- İş: Kabul edilmiş teklif, hazırlık/atölye reçetesi, kalite, sevk, ön koşul formu, servis raporu ve devreye alma belgesini aynı iş altında sürümüyle listele. Zorunlu/eksik/hazırlanıyor/hatalı durumlarını göster.
- Kabul: Kullanıcı her belgenin hangi kayıt/sürüme ait olduğunu anlar. Son belge eski onaylı belgeyi silmez. Taslak açıkça işaretlidir.
- Test: Eksik dosya, yetkisiz indirme, güncellenmiş şablon, yanlış iş bağlantısı.

### F9-02 — PDF tutarlılığı ve üretim kuyruğu

- İş: Mevcut PDF servislerini sabit kayıt/sürüm kaynaklarına bağla. Tekrar üretimde içerik/veri sürümü korunur; içerik hash'i ve üretim sonucu izlenir. Türkçe karakter, uzun satır ve çok sayfa örneklerini görsel kontrol et.
- Kabul: PDF tutar/kapsam/ölçüm bilgisi kaynakla aynıdır; metin taşması ve kayıp imza alanı yoktur. Hatalı üretim tekrar denenebilir; ana kayıt çoğalmaz.
- Test: Büyük kalem listesi, uzun unvan, Türkçe, görselsiz rapor, çok fotoğraf, üretim kesintisi. Haricî Drive entegrasyonu eklenmez.

### F9-03 — Müşteri geri bildirimi ve aksiyon

- İş: İş tamamlandıktan sonra satış sorumlusuna müşteriye dönüş görevi aç. Müşteri yorumunu teklif/iş/ziyaret bağlantısıyla kaydet; memnuniyet veya eksik iletişim için sorumlu/tarih/sonuç tut.
- Kabul: Müşteri beyanı ile personelin çözüm notu ayrı saklanır. Aksiyon gecikince takip görünür. Bu ekran bağımsız arıza kabul merkezine dönüşmez.
- Test: Aynı kapanış olayında tek takip görevi, erişim ayrımı, kapatılıp yeniden açılan aksiyon.

### F9-04 — Tek cari zaman çizelgesi

- İş: Görüşme, teklif gönderim/yanıt, kabul, üretim, sevk, servis, rapor, devreye alma ve geri bildirim olaylarını kaynak bağlantılarıyla göster. İç teknik hata olaylarını müşteri iletişim geçmişinden ayır.
- Kabul: Cari ekranından işin bütün geçmişi açılır; aynı olay farklı modüllerden iki kere görünmez. Olay zamanı ve kaydedilme zamanı gerekiyorsa ayrı gösterilir.
- Test: Eski verinin eksik zamanları, yetkiye göre gizli notlar, sıralama ve sayfalama.

Faz çıkışı: Müşteriye ve işe ait doğrulanmış belge/geçmiş dosyası hazır; takip döngüsü iş tesliminde kopmuyor.

## F10 — Ortak deneyim, yönetici görünümü ve operasyon izleme

Amaç: Çalışan zinciri herkesin kolay kullanacağı kurumsal deneyime dönüştürmek.

Ön koşul: F9. Görsel iyileştirme bu faza kadar tamamen beklemez; her fazın kendi ekranı kullanılabilir teslim edilir.

### F10-01 — Menü ve ortak iş özeti

- İş: Ana plandaki menüyü rol bazında düzenle; ortak başlık, durum, sorumlu, termin, engel ve kaynak bağlantı bileşenlerini kullan. İki uygulama arasında geçiş gerekiyorsa seçili iş ve oturum bağlamını koru.
- Kabul: Kullanıcı teknik uygulama adlarını bilmeden teklifinden işine ulaşır. Aynı eylem farklı ekranlarda farklı anlam taşımaz.
- Test: Derin bağlantı, oturum süresi dolması, geri gezinme, mobil/masaüstü genişlikleri. Mevcut değişmiş `my_workspace_page.dart` kullanıcı çalışması korunarak uyarlanır.

### F10-02 — Rol bazlı Masam ve eskalasyon

- İş: Satış, hazırlık, atölye, koordinatör ve teknisyenin kuyruklarını aynı görev kaynağından üret. Gecikmiş, bekleyen onay ve blokajı ayrı göster; yöneticide ekip filtresi sun.
- Kabul: Her aktif iş sorumluya düşer. Ertelenmiş görevle tamamlanmış görev karışmaz. Aynı uyarı tarama başına çoğalmaz.
- Test: Sorumlu devri, iş günü/saat dilimi, izne ayrılan kullanıcının yeniden ataması, aşama değişiminde eski uyarının kapanması.

### F10-03 — Süreç raporları

- İş: Teklif dönüşümü, takip uyumu, hazırlıkta bekleme, üretim gecikmesi, servis rapor süresi ve müşteri aksiyonları için tanımlı pay/payda ve tarih filtresi kullan. Her sayıdan kaynak kayıt listesine inilebilsin.
- Kabul: Revizyonlar satış sayısını şişirmez. Farklı para birimleri doğrudan toplanmaz. Dönem ve kapsam ekranda görünür. Henüz veri yoksa uydurma metrik gösterilmez.
- Test: Küçük sabit veri setinde elle hesapla karşılaştır; kaybedilmiş, iptal, çok paket ve iki ziyaret örneklerini dahil et.

### F10-04 — Otomasyon işletimi ve performans

- İş: Başarısız/bekleyen olayları, son denemeyi, ilişkiyi ve yetkili yeniden denemeyi göster. Büyük listelere indeks/sayfalama ekle; pilot hacminde ölç. Hassas form/imza içeriğini loglara koyma.
- Kabul: Bir işin neden ilerlemediği hata ekranından bulunur. Yeniden deneme ikinci iş/belge yaratmaz. Performans ölçümü ortam ve veri hacmiyle kaydedilir.
- Test: Kasıtlı PDF/olay hatası, tüketicinin durması, kurtarma, izinli/izinsiz tekrar deneme.

Faz çıkışı: Sistem görevleri yalnız saklamıyor, işin nerede ve kimde beklediğini açıklıyor.

## F11 — Pilot, veri geçişi ve eski yolların kapatılması

Amaç: Yeni akışı gerçek kullanımda kanıtlamak ve eski karışıklığa geri dönmesini engellemek.

Ön koşul: Pilotta kullanılacak F0–F10 paketleri kabul edilmiş. Üretim değişikliği için mevcut oturumdaki yetkilendirme ve kurumun dağıtım süreci izlenir; bu planın hazırlanması tek başına canlı değişiklik isteği değildir.

### F11-01 — Taşıma provası ve mutabakat

- İş: Yedekten geri yüklenebilir test ortamında müşteri, teklif, iş ve atölye bağlantılarını taşı. Kimlik eşleme ve işlem manifestini sakla. Önce/sonra sayı, kapsam miktarı, teklif tutarı, belge bağlantısı ve erişimi karşılaştır.
- Kabul: Açıklanamayan kayıp ve mükerrer yoktur. Belirsiz kayıtlar raporludur. Tekrar taşıma ikinci kopya oluşturmaz. İki uygulama aynı kayıt sürümünü doğru okur.
- Test: Eksik müşteri, bozuk eski açıklama, elle açılmış iş, çelişkili kabul, iki migration dizisinde aynı SQL.

### F11-02 — Uçtan uca kullanıcı kabulü

- İş: `03-UCA-DAN-UCA-KABUL-SENARYOLARI.md` senaryolarını ilgili iş rolüyle yürüt; normal ve hatalı geçiş kanıtını kaydet. Kritik veri/yetki hatalarını kapatmadan pilotu genişletme.
- Kabul: Tekliften kapanışa ana zincir, yeniden çalışma ve tekrar istekler geçer. Çalıştırılmayan senaryo "geçti" yazılmaz. Kullanıcı kendi işini açıklama desteği olmadan tamamlayabilir.
- Çıktı: Tarihli UAT kaydı, bilinen sınırlamalar ve ürün sahibinin değerlendirmesi.

### F11-03 — Kontrollü açılış ve geri dönüş

- İş: Küçük kullanıcı/iş kapsamıyla özellik bayrağını aç; yeni işlerde yeni yazma yolunu zorunlu tut. Eski yoldan kontrollü durum atlamayı kapat. Geri dönüşte yeni kayıtları koruyan uygulama/okuma uyumluluğunu prova et.
- Kabul: Eski istemci yeni kayıtları kontrolsüz değiştiremez. Geri dönüş veriyi silmez. Yedek geri yükleme testinin sonucu ve olay kuyruğu kurtarma adımları mevcut.
- Test: Açılış sonrası eski sürüm istemci, otomasyon kesintisi, rollback sırasında yeni kayıt varlığı.

### F11-04 — Sadeleştirme, eğitim ve bakım devri

- İş: Kullanılmayan mükerrer yolları kullanım kanıtıyla kaldır/gizle; eski veriye okunur erişimi koru. Her rol için kısa çalışma rehberi, hata müdahale rehberi ve sürüm notu oluştur. Sonraki kapsam listesine yalnız arıza/bağımsız rotaları not et.
- Kabul: Çalışan ana akışın sahibi, destek sorumlusu, yedekleme/geri yükleme prosedürü ve düzenli takip ekranı bellidir. "Tüm sistem" diye kapsam dışı finans/arıza özellikleri açılmaz.

Faz çıkışı: Ürün sahibinin ana akışı gerçek ekipte çalışıyor; veri geçişi ve geri dönüş kanıtlı; eski yollar yeni kuralları aşamıyor.

## Teslim büyüklükleri ve başlangıç sırası

1. İlk çalışma oturumu: F0-01. Amaç yeni özellik yazmak değil mevcut sistemi doğrulamak.
2. İlk teknik temel: F1-01–04. Bu işler ana akışın güvenilirliğine hizmet eder; bağımsız altyapı projesine dönüşmez.
3. İlk kullanıcı değeri: F2–F3. Müşteri ve teklif takibi düzenlenir.
4. İlk zincir demosu: F4. Kabulden otomatik hazırlık iş emri oluşur.
5. Ana hedefin tamamlanması: F5–F8. Atölyeden devreye almaya geçilir.
6. Kurumsal tamamlanma: F9–F11. Geçmiş, belgeler, izleme ve gerçek kullanım sağlamlaştırılır.

48 paketin tamamı aynı büyüklükte değildir. Uygulayıcı bir paketin tek incelemede değerlendirilemeyeceğini görürse `F4-02a`, `F4-02b` gibi alt paket açabilir; ana kabul koşulunu daraltamaz veya tamamlandı sayamaz. Takvim ve maliyet tahmini gerçek başlangıç ölçümleri olmadan taahhüt edilmez.

---

## Bölüm 2 — Durum makineleri, otomasyon sözleşmeleri, yetki ve fazlar

Kabul kapısı: geçerli revizyon, cari/tesis, kapsam, miktar, mutabık bedel, para/kur bilgisi, operasyon rotası ve kanıt/kaydeden belli olmalıdır. Süresi dolmuş teklif ancak gerekçeli yeniden doğrulamayla kabul edilebilir. "E-posta uygulaması açıldı" veya "WhatsApp paylaşım ekranı açıldı" teslim edildi kanıtı değildir; manuel gönderim beyanı ayrı gösterilir.

### Ana iş ve hazırlık

Ana iş: `preparation → ready → active → operationally_complete → closed`, ayrıca `on_hold/cancelled`. Hazırlıkta eksikler olabilir; iş sorumlusu yine bellidir. Teknik hazırlık tamamlanmadan `ready` olmaz. `active`, ilgili üretim/saha paketleri başladığında hesaplanır.

Hazırlık kapısı: onaylı kapsam ve teknik sürüm, teslim planı, paketler, atamalar, malzeme durumu ve gerekli belgeler. Satışa geri soru açık görevle döner; teklif kabulü silinmez. `operationally_complete`, rotadaki zorunlu paketler ve kabul belgeleri bittiğinde oluşur. Finansal kapanış ayrı boyuttur; ödenmemiş olması saha işini geriye döndürmez.

### Atölye ve sevkiyat

Atölye: `preparing → ready → in_production → quality_check → ready_to_ship → shipped`. `blocked` için neden/sorumlu/tarih; kalite başarısızsa `rework → quality_check`. Üretim tamamlandı, kalite onaylandı ve sevk edildi ayrı olaylardır.

Kalite kapısı: zorunlu maddeler tamam, ölçümler tanımlı kurala uygun, fotoğraflar ve onaylayan kayıtlı; engelleyici uygunsuzluk açık değil. Şablonun teknik eşikleri D07 ile belirlenir. Sevkiyat miktarı kalite kabulünden geçen miktarı aşamaz. Kısmi sevkte kalan miktar açık kalır.

### Servis ve rapor

Talep: `draft → awaiting_readiness → ready_to_plan → scheduled → in_service → report_review → completed`. Hazır olmayan saha planlamayı bloke eder. İptal ve erteleme nedenlidir; tarih değişimi geçmişte görünür. Ziyaret iptali talebi kendiliğinden kapatmaz.

Rapor: `draft → submitted → approved`, düzeltme için `returned → draft`; onay sonrası yeni sürüm. Onaysız rapor devreye alma hazırlığını tamamlanmış saydıramaz. Müşteri imza vermediyse "imzasız/gerekçeli bekliyor"; sahte otomatik onay yok. Teknisyen kendi işini müşteri adına kabul edemez.

### Devreye alma ve kabul

`draft → ready → scheduled → testing → pending_customer_acceptance → accepted`. Başarısız test `correction_required → testing`; koşullu kabul ancak tanımlı yetki ve engelleyici olmayan eksiklerle `conditionally_accepted` olur. Koşullu kabul tam kapanış değildir; açık eksikler takip edilir.

Başlatma kapısı: gerekli servis raporları onaylı, ilgili cihaz/paketler hazır, gerekli saha koşulları tamam. Form taslağı otomatik oluşabilir; yapılan testler otomatik "geçti" işaretlenmez. İş türünde devreye alma yoksa rota bunu gerekçeli olarak başlangıçta belirtir; sessiz atlama yapılmaz.

### İptal ve kapsam değişikliği

Kabul sonrası ticari değişiklik yeni değişiklik emri/kabul sürümüyle gelir. Üretilmiş, sevk edilmiş veya sarf edilmiş işler silinmez. Henüz başlamayan paketler gerekçeyle iptal edilir; kullanılan malzeme ve tahsilatlar gerekiyorsa ters hareketle düzeltilir. İade/yeniden servis eski işi değiştirmek yerine ona bağlı takip kaydı açar.

## 7. Otomasyon sözleşmeleri

### A01 — Teklif kabulünden iş emri

Tetikleyici: Yetkili kullanıcı belirli teklif revizyonunu ve kapsamını kabul ettirir. Tek sunucu işlemi kabul kaydını, sabit kapsamı, ana iş emrini ve hazırlık görevini oluşturur; olay kuyruğuna kayıt bırakır. İstek anahtarı ve kabul kaydı başına eşsiz iş emri kısıtı kullanılır. Aynı istek iki cihazdan gelse de tek iş oluşur. Hata halinde işlem bütünü geri alınır; kullanıcı "kazanıldı ama iş yok" durumunda bırakılmaz. Yanıt `acceptance_id`, `work_order_id`, durum ve tekrar isteği bilgisi döndürür.

### A02 — Hazırlıktan atölyeye

Tetikleyici: Teknik hazırlık sorumlusu belirli paket/sürümü serbest bırakır. Yalnız imalat gerektiren paketler için atölye kaydı oluşur; sorumlu kuyruğuna düşer. Aynı paketi tekrar serbest bırakmak ikinci reçete oluşturmaz. Reçete düzeltmesi yeni sürümdür.

### A03 — Atölye çıkışından servis hazırlığına

Tetikleyici: Sahaya gidecek kapsamın sevkiyatı kaydedilir. Paket veya sevkiyat grubu için tek servis talebi/ön koşul formu taslağı açılır; koordinatöre görev verilir. Kısmi sevkiyatlar aynı talepte birleşecekse grup anahtarı kullanılır. Gönderim öncesi taslak hazırlamak mümkündür; "saha hazır" sayılmaz. Müşteriye kendiliğinden mesaj gönderilmez.

### A04 — Ön koşul onayından planlamaya

Tetikleyici: Geçerli form sürümü gerekli cevaplarla onaylanır. Talep planlamaya hazır olur, koordinatör görevi açılır. İptal edilmiş veya süresi geçmiş form cevapları işlenmez. Tarih/ekip otomatik atanmaz; saha uygunluğu doğrulanır.

### A05 — Rapor onayından devreye almaya

Tetikleyici: İlgili kapsam için son gerekli servis raporu onaylanır. Rota gerektiriyorsa tek devreye alma taslağı, cihaz listesi ve yapılacak kontroller oluşur. Yeni ziyaret raporu aynı kapsam için mükerrer form açmaz. Eksik veya uygunsuz rapor taslağı bloke eder.

### A06 — Kabulden kapanışa

Tetikleyici: Devreye alma/müşteri kabulü tamamlanır. Zorunlu kapsam, belgeler ve eksikler kontrol edilir. Operasyon tamamlanma olayı ve belge üretim işi oluşturulur. Finans kontrol görevi ayrı açılır; fatura ya da tahsilat kendiliğinden yapılmış sayılmaz.

### A07 — Takip ve eskalasyon

Tetikleyici: Sonraki aksiyon tarihi veya aşama hedef süresi geçer. Aynı kayıt+aşama+eşik için tek açık uyarı oluşturulur. Önce sorumlu, tanımlı ikinci eşikte yöneticisi bilgilendirilir. Başlangıç önerisi teklif sonrası 2 iş günü takip, 5 iş günü ikinci hatırlatma; bunlar ölçülmüş değer değil, değiştirilebilir pilot ayarıdır. İş takvimi, duraklama gerekçesi ve saat dilimi tanımlanır. Sistem aynı uyarıyı her taramada çoğaltmaz.

### A08 — Dayanıklılık ve izleme

Veri değişikliği ile olay kuyruğu aynı veritabanı işlemindedir. Bildirim/PDF/dış entegrasyon ayrı tüketiciyle çalışır. Önerilen tekrar aralıkları 1, 5, 30 dakika, 2 saat ve 12 saat; sonrasında hata kuyruğu ve yöneticiye görev. Bu değerler ayardır. Her tüketici `(event_id, consumer)` eşsizliğiyle tekrar güvenlidir. Kaybolan yanıt yeniden çalıştırmayı güvenli kılar. İşlem tamamlandıktan sonra PDF hatası iş emrini geri almaz; belge durumu "üretilemedi" ve tekrar eylemi görünür. Yetkisiz, geçersiz durum, eksik alan ve eşzamanlı değişiklik hataları otomatik tekrar edilmez.

## 8. Yetki ve belge politikası

Yetki = işlem izni + sahip kuruluş kapsamı + atanmış ekip/müşteri kapsamı. Menü gizleme yeterli değildir. Sunucu, dosya erişimi, liste sorguları ve tekil kayıt işlemleri aynı sınıra uyar. Rol adları mevcut uygulamayla eşlenir; aşağıdakiler iş sorumluluklarıdır, zorunlu yeni rol enum'u değildir.

- Satış: yetkili cariler, fırsatlar, teklif hazırlama ve takip; maliyet/iskonto sınırı ayrı izin.
- Satış yöneticisi: ekip görünümü, istisna onayı, yeniden atama ve kazanım doğrulama.
- İş hazırlama: kabul edilmiş teknik kapsam, paket ve reçete hazırlama; kabul fiyatını değiştiremez.
- Atölye: atanmış üretim ve ölçümler; kalite onayı ayrı yetki. Ticari marjı varsayılan olarak görmez.
- Servis koordinatörü: saha hazırlığı, planlama, atama, rapor inceleme.
- Teknisyen: atanmış ziyaret, malzeme/süre/rapor taslağı; finans ve müşteri adına onay yok.
- Finans: cari hareket, tahsilat, ekstre ve düzeltme; üretim test sonucu değiştiremez.
- Yönetim: kapsam içi raporlar ve istisnalar; kritik değişiklikler yine iz bırakır.
- Müşteri/dış partner: yalnız açıkça paylaşılan kayıt, onaylanan alanlar ve belgeler; iç not/maliyet erişimi yok.

Onaylı belge içerik ve şablon sürümüyle sabitlenir. Yeni şablon eskiden imzalanan metni değiştirmez. Açık müşteri bağlantısı ayrı erişim anahtarıyla sınırlanır; ham kayıt ID'si izin değildir. Form cevapları ve imza onayı sunucuda doğrulanır. İmza görselinin kaydı kendiliğinden nitelikli elektronik imza olduğu iddiasıyla sunulmaz.

## 9. Fazlar ve bağımlılıklar

F0 Gerçek envanter ve kararlar → F1 ortak model/yetki/işlem altyapısı → F2 cari ve takip → F3 teklif ve revizyon → F4 kabulden iş emrine → F5 iş hazırlama/atölye → F6 sevkiyat/servis talebi → F7 saha ve rapor → F8 devreye alma/kabul.

F9 cari hesap, F2 ve ticari belge sözleşmesi hazır olduğunda geliştirilebilir; F8 bitişine teknik olarak bağlı değildir. F10 ortak deneyim/raporlar son birleştirmeyi yapar; temel Masam ve hata görünürlüğü önceki fazlarda zaten teslim edilir. F11 pilot, geçiş ve sadeleştirme tüm kullanılacak fazların kabulüne bağlıdır.

**İlk değerli teslim:** F0–F4 sonunda cari → proje → teklif → takip → kabul → otomatik hazırlık iş emri zinciri çalışmalı. Bu ilk sürüm bütün ürünün tamamlandığı anlamına gelmez.

**Ana operasyon teslimi:** F5–F8 sonunda atölye → servis → rapor → devreye alma zinciri aynı işten yürümeli.

**Kurumsal kullanım teslimi:** Cari hesap, rol bazlı ortak ekranlar, hata izleme, pilot ve geri dönüş kanıtıyla tamamlanmalı.

Takvim taahhüdü verilmemiştir. Önce F0'da gerçek kapsam ve bağımlılıklar, ardından ilk iki iş paketindeki gerçek süre/engel ölçülür. Faz büyüklüğü story point veya ajan token sayısı yerine doğrulanabilir iş paketleriyle yönetilir. Bir pakete veri taşıma + tüm ekranları yenileme + yeni iş kuralı birlikte yüklenmez.

## 10. Veri geçişi ve sürdürülebilir mimari

1. Uygulanan migration listesi, tablolar, tetikleyiciler, RLS, Storage kuralları ve kullanılan fonksiyonlar salt okunur çıkarılır. Tek migration kaynağı seçilir; eski SQL dosyaları körlemesine tekrar çalıştırılmaz.
2. Şema değişiklikleri önce eklemeli olur. Yeni alan/tablolar eklenir; eski uygulama çalışmaya devam eder.
3. Müşteri eşleme tablosu kurulur: eski kaynak ve ID → hedef cari/tesis. Belirsiz kayıtlar inceleme kuyruğuna ayrılır. İsim benzerliğiyle geri dönüşsüz birleştirme yapılmaz.
4. Eski teklifler için ham durum, müşteri yanıtı, gönderim bilgisi korunur. Çelişkili kayıtlar `needs_review` işaretiyle taşınır; eski kabul kanıtı uydurulmaz.
5. Eski atölye kartları yeni üretim tipine doğrulanarak bağlanır. Açıklamadan çıkarılamayan teknik veri "eksik" kalır; hayalî reçete üretilmez.
6. Pilot kapsam kayıtları önce taşınır. Kayıt sayısı, satır/miktar/tutar, belge ve ana-yavru ilişki mutabakatı yapılır. Taşıma tekrar çalıştırılınca yeni kopya yaratmaz.
7. Yeni yazma yolu açılırken aynı kayda kontrolsüz iki uygulama yazması engellenir. Paylaşılan sunucu işlemi veya salt okunur eski ekran kullanılır. İstemciden bağımsız çift yazma kabul edilmez.
8. Geri dönüş, yeni yazıları kaybetmeden eski okuma uyumluluğunu sürdürme planıdır. Veri üretilmiş tabloları düşürmek rollback değildir.
9. Eski alanlar ancak pilot ve mutabakat tamamlanınca kullanım ölçümüyle emekliye ayrılır.

Teknoloji değişimi bu planın ön şartı değildir. Mevcut Flutter/Supabase yapısında modül bazlı domain/application/data/presentation sınırları ve sunucu işlem sözleşmeleri kurulabilir. Mevcut `TicketRepository` yaklaşımı genişletilebilir. Kritik iş kuralı büyük ekran widget'ının içinde kalmamalı; yeni bir genel workflow platformu yazmak da kapsam değildir.

## 11. Başarı ölçütleri

Başlangıç değerleri bilinmiyor; Faz 0/pilot öncesinde ölçülecek. Aşağıdakiler hedef tanımlarıdır, mevcut performans iddiası değildir.

- Kabulden iş emrine: başarılı her kabulde tam bir ana iş; eşzamanlı/tekrar isteklerde sıfır mükerrer.
- İzlenebilirlik: pilotta her yeni işten kaynak kabul revizyonu, müşteri ve zorunlu alt belgeler açılabilir.
- Sorumluluk: aktif pilot kayıtlarının tamamında sorumlu ve sıradaki iş/termin veya gerekçeli bekleme bulunur.
- Teklif hazırlama süresi: aynı örnek kapsam ve kullanıcıyla önce/sonra ölçülür; hedef iyileşme pilot başında kararlaştırılır.
- Takip uyumu: vadesinde tamamlanan takip / vadesi gelen takip. Açık/gecikmiş ve ertelenmiş görevler ayrı raporlanır.
- Kazanım oranı: seçilen dönemde kararı sonuçlanmış fırsatlar içinde kazanılanlar; teklif revizyonları ayrı satış gibi sayılmaz.
- Teslim uyumu: taahhüt edilmiş paket terminine karşı gerçek teslim. Kısmi/tam teslim ayrı.
- Kalite: yeniden işleme dönen paket / kontrol edilen paket; örneklem ve dönem görünür.
- Servis: ilk ziyarette çözüm ve rapor onay süresi; iptal/no-show paydaları tanımlı.
- Finans: para birimi bazında kesinleşmiş borç − alacak; vadesi geçen bakiye ayrı. Kabul bedeli bakiye değildir.
- Otomasyon: başarısız/bekleyen olay sayısı ve en eski olay yaşı; başarısızlık görünmez kalmaz.

## 12. Uygulama yönetimi

Her paket için ürün sorumlusu, teknik uygulayıcı ve kabulü yapacak kullanıcı belirlenir. Bir ajan "bitti" dediği için paket kapanmaz: iş senaryosu, hata senaryosu, yetki kontrolü ve gerekiyorsa veri mutabakatı kanıtı gerekir. Mevcut bir hata yeni işin başarısı gibi gizlenmez; test başlangıç durumu ve yeni sonuç ayrı yazılır.

Her faz sonunda işletme diliyle kısa demo yapılır: "Müşteri kabul edince ne oldu, kimin masasına düştü, hangi bilgi taşındı, eksikse ne oldu?" Cevap net değilse faz tamamlanmış değildir.
