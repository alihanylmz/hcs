# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini me tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-016] - 2026-08-13 (15:15 +03:00)

### 📌 Başlık
Zimmet Silinmesi/Kapanması, Arızalı/Hurda Otomatik Filtreleme, Seri No Araması ve Her Tablo İçin PDF Raporlama Sistemi

### 🎯 Değişiklik & İşlem Özeti
1. **Zimmetin Otomatik Kapanması & Personelden Düşmesi (`lib/services/stock_service.dart`):**
   - Zimmetlenen ürün sarf edildiğinde, iade alındığında veya arızaya ayrıldığında toplam zimmet miktarı tamamlandığında (`remainingQty <= 0`) zimmet kaydı veritabanında otomatik olarak kapatılıyor (`status = 'returned'` / `'consumed'`).
   - Bu sayede personele ait aktif zimmet listesinden (`getOpenPersonnelLoans`) işlem gören ürün anında siliniyor ve temizleniyor.

2. **Arızalı Ürünler (RMA) Temizliği (`lib/services/stock_service.dart`):**
   - Arızalı ürünler tablosunda tamir edilip depoya dönen (`repaired_returned`), yenisi ile değiştirilen (`replaced`) veya hurdaya ayrılıp çöpe atılan (`scrapped`) kayıtlar aktif RMA tablosundan otomatik olarak filtrelendi (`getDefectiveProducts(onlyActive: true)`). Sadece takibi devam eden ürünler gösteriliyor.

3. **Seri No ve Notlarda Arama (`lib/pages/stock_overview_page.dart`):**
   - Arama çubuğu filtreleme algoritmasına `specifications` (ürün özellikleri / seri no) ve `notes` alanları eklendi. Ürünlerin notlarına veya özelliklerine yazılan seri numaraları aratıldığında doğrudan listeleniyor.

4. **Tüm Stok Tabloları İçin Kurumsal PDF Raporlama (`lib/services/stock_pdf_service.dart`):**
   - Depo Stokları, Kritik Stoklar, Ürün Kataloğu, Personel Zimmetleri Ekstresi, Arızalı Ürünler (RMA) ve Stok Hareket Logları için özel Türkçe PDF rapor oluşturucuları yazıldı.
   - Stok ERP ana sayfasına **`[📄 PDF Rapor Al]`** butonu eklendi. Kullanıcı hangi sekmedeyse tek tıkla o tablonun detaylı PDF raporunu görüntüleyip indirebiliyor.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/services/stock_pdf_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-015] - 2026-08-13 (15:00 +03:00)

### 📌 Başlık
Zimmetten Arızalıya Ayrıştırmada Mükerrer Depo Stok Düşümünden Kaynaklanan 'Stok Yetersiz' Hatasının Çözülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Mükerrer Stok Düşümü Hata Tespiti (`lib/services/stock_service.dart`):**
   - Personele zimmet verilirken (`register_product_stock_loan`) ürün miktarı depodaki fiziki stoktan zaten düşüldüğü için (`products.stock_quantity`), zimmet dönüşünde ürünü arızalıya ayırırken veya sarf ederken `register_product_stock_movement(out)` metodunun tekrar çağrılması stok miktarını eksiye (`< 0`) düşürmeye çalışıyor ve Postgres `Stok yetersiz! Mevcut: 0.00` hatasını fırlatıyordu.

2. **Geliştirilen Çözüm (`logStockMovementAudit` & `deductFromWarehouseStock: false`):**
   - Zimmet dönüşü işlemlerde (Sarf ve Arızalı ayrıştırma) fiziki depodan ikinci kez stok düşülmemesi sağlandı. Sadece stok hareket logu (`logStockMovementAudit`) ve arızalı ürün kaydı (`defective_products`) oluşturuldu.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
