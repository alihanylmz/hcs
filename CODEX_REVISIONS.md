# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-003] - 2026-08-13 (11:51 +03:00)

### 📌 Başlık
Stok ERP Güncellemelerinin `.info` (Staging/Test) Ortamına Yayınlanması (Deploy)

### 🎯 Değişiklik & İşlem Özeti
- **Yayın Hedefi:** `.info` ortamı (`uzalteknikservis.info`).
- **İşlem:** Yerel web derlemesi doğrulandıktan sonra değişiklikler `test` dalına push edilerek Plesk FTP Deploy GitHub Actions iş akışı (`deploy-test-site.yml`) tetiklendi.
- **Dağıtım Kapsamı:** `/is-takip/` ve `/teklif/` web uygulamaları güncellenerek yenilenen stok yönetimi ERP modülü staging alanında yayınlandı.

### 📁 Etkilenen Dosyalar
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-002] - 2026-08-13 (11:29 +03:00)

### 📌 Başlık
Stok Servisi ve Ana Stok Sayfası (StockOverviewPage) ERP Standartlarına Dönüştürülmesi & Temizlenmesi

### 🎯 Değişiklik & İşlem Özeti
1. **`StockService` Katmanında Tablo Standartlaşması ve RPC Entegrasyonu (`lib/services/stock_service.dart`):**
   - Eski `inventory` tablosu bağımlılıkları temizlenip tamamen `products` tablosu üzerinde standartlaştırıldı.
   - Stok giriş (IN) ve çıkış (OUT) işlemleri Supabase RPC `register_product_stock_movement` sunucu kilidine bağlandı.
   - Personel zimmet verme (`register_product_stock_loan`), zimmet kapatma (`close_product_stock_loan`) ve yetkili personel listeleme (`list_stock_personnel`) RPC entegrasyonları tamamlandı.
   - `addPartToTicket` ve `removePartFromTicket` servis metotları `products` tablosu ve atomik stok miktarlarıyla güncellendi.
   - İş emri stok düşümlerinin geriye uyumluluğu korundu.

2. **`StockOverviewPage` Arayüzünün Yenilenmesi (`lib/pages/stock_overview_page.dart`):**
   - 3.700 satırlık karmaşık monolitik yapı temizlenerek modüler, okunabilir ve yüksek performanslı DataGrid arayüzüne kavuşturuldu.
   - **Elektronik Tablo Korundu:** `.agents/AGENTS.md` kuralı uyarınca görünüm profesyonel ERP DataGrid (Table) formatında tutuldu.
   - **Modüller & Sekmeler:**
     - *Tüm Stoklar (DataGrid):* Kod, Ürün Adı, Kategori, Marka/Model, Miktar (Renk Rozetli), Raf Lokasyonu (`shelf_location`), Barkod ve Hızlı İşlemler.
     - *Kritik Stoklar:* Asgari stok seviyesindeki ürünler ve hızlı sipariş PDF dökümü.
     - *Personel Zimmetleri:* Sahadaki teknik personelin zimmetindeki ürünler ve tek tıkla iade/tüketildi kapatma diyalogları.
     - *Stok Hareket Logları:* Kimin ne zaman stok girip çıktığının audit dökümü.
     - *Eksik Malzemeli İşler:* İş emirlerinde ihtiyaç duyulan malzemelerin takibi ve iş detayına yönlendirme.
   - **Hızlı Aksiyonlar & Diyaloglar:** Yeni Ürün Ekle/Düzenle, Hızlı Stok Giriş/Çıkış (IN/OUT), Personele Zimmetle, Barkod Okutma ve Seçilenlerden Sipariş PDF Listesi Oluşturma eklendi.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-001] - 2026-08-13 (11:15 +03:00)

### 📌 Başlık
Stok/Katalog Sistemi Teşhisi, Profesyonelleştirme Yol Haritası ve İlk Yapılandırma

### 🎯 Değişiklik & İşlem Özeti
- **Kapsam:** Stok ve Ürün Kataloğu mimarisi detaylı olarak incelendi (`lib/services/stock_service.dart`, `lib/pages/stock_overview_page.dart`, `uzalteklif/lib/screens/home_page.dart`, Supabase migration dosyaları).
- **Mevcut Durum Analizi & Amatör Görünen/Sıkıntı Yaratan Unsurlar:**
  1. **Çift Tablo Karışıklığı (`inventory` vs `products`):** Sistem yer yer `inventory` yer yer `products` tablosuna erişiyor. `StockService` içindeki bazı metotlar `products` tablosunu güncellerken, `updateQuantity` ve `addPartToTicket` `inventory` tablosuna bakıyor. Bu durum veri tutarsızlığına yol açıyor.
  2. **İsim String'ine Dayalı Stok Düşümü (`decreaseStockByName`):** İş emirlerinden stok düşerken "Marka Model kW Sürücü" gibi metin birleştirerek arama yapılıyor. Küçük bir yazım hatası veya boşluk stok düşümünü tamamen başarısız kılıyor. Ürün ID (`product_id` veya `barcode`) bazlı ilişki kurulmalı.
  3. **İstemci Taraflı Read-Modify-Write Riskleri:** Eski metotlar istemci tarafında sayı çekip düşerek yazıyor (Race Condition riski). Oysa Supabase RPC (`register_product_stock_movement`, `register_product_stock_loan`) sunucu tarafında `FOR UPDATE` kilit kullanarak doğru mimariye geçirilmiş fakat Dart tarafındaki eski kodlar tamamen temizlenmemiş.
  4. **Monolitik & Devasa UI Dosyaları:** `stock_overview_page.dart` (3700+ satır) tek bir dosyada tüm sekme, diyalog, barkod, PDF export ve form mantığını barındırıyor. `Map<String, dynamic>` veri taşıması yerine strongly-typed modeller ve modüler widget mimarisine geçilmeli.
  5. **Depo/Kasa/Raf Yönetimi Eksikliği:** Profesyonel ERP stok sistemlerinde olması gereken minimum stok seviyesi uyarısı, otomatik sipariş listesi, lokasyon hiyerarşisi (Ana Depo -> Kasa -> Raf), serino/lot takibi ve birim maliyet/FIFO hesaplaması arayüzde tam entegre değil.

### 📁 Etkilenen Dosyalar
- `[NEW] CODEX_REVISIONS.md` (Codex revizyon takip dosyası oluşturuldu)

### 🚀 Önerilen Profesyonelleştirme Adımları (Plan)
1. **Tek Tablo Standartlaşması:** Tüm stok/ürün verilerini `products` tablosunda birleştirmek, `inventory` tablosunu legacy adapter ile izole etmek.
2. **Strict Entity IDs & Barcode Scanner Entegrasyonu:** Metinle ürün araması yerine UUID / Barkod / Karekod eşleşmesiyle %100 kesin stok hareketleri sağlamak.
3. **RPC Tabanlı Atomik Hareketler:** Tüm stok giriş/çıkış/zimmet işlemlerini sadece Supabase Edge RPC `register_product_stock_movement` üzerinden yürütmek.
4. **UI Modülerleştirme:** `stock_overview_page.dart` sayfasını alt bileşenlere (Stok Listesi, Hareketler, Zimmetler, Eksik Malzemeler, Barkod Tara) ayırmak ve elektronik tablo / tablo düzenini koruyarak profesyonel ERP UI/UX standartlarına taşımak.

---
