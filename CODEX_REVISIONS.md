# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-015] - 2026-08-13 (15:00 +03:00)

### 📌 Başlık
Zimmetten Arızalıya Ayrıştırmada Mükerrer Depo Stok Düşümünden Kaynaklanan 'Stok Yetersiz' Hatasının Çözülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Mükerrer Stok Düşümü Hata Tespiti (`lib/services/stock_service.dart`):**
   - Personele zimmet verilirken (`register_product_stock_loan`) ürün miktarı depodaki fiziki stoktan zaten düşüldüğü için (`products.stock_quantity`), zimmet dönüşünde ürünü arızalıya ayırırken veya sarf ederken `register_product_stock_movement(out)` metodunun tekrar çağrılması stok miktarını eksiye (`< 0`) düşürmeye çalışıyor ve Postgres `Stok yetersiz! Mevcut: 0.00` hatasını fırlatıyordu.

2. **Geliştirilen Çözüm (`logStockMovementAudit` & `deductFromWarehouseStock: false`):**
   - Zimmet dönüşü işlemlerde (Sarf ve Arızalı ayrıştırma) fiziki depodan ikinci kez stok düşülmemesi sağlandı. Sadece stok hareket logu (`logStockMovementAudit`) ve arızalı ürün kaydı (`defective_products`) oluşturuldu.
   - İade edilen miktarlar ise (`returnedQty > 0`) depodaki fiziki stok miktarına sorunsuz şekilde geri eklendi.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-014] - 2026-08-13 (14:55 +03:00)

### 📌 Başlık
Stok Tablosu 'İşlemler' Hücrelerinin Kurumsal 'Stok İşlemleri ▾' Menü Butonuna Dönüştürülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Görsel Kalabalığın Temizlenmesi (`lib/pages/stock_overview_page.dart`):**
   - Stok tablosundaki her satırda yan yana sıkışmış duran 3 ayrı buton (`+ Giriş`, `- Çıkış`, `Zimmetle`) kaldırılarak kurumsal **`[Stok İşlemleri ▾]`** butonuna dönüştürüldü.
   - Butona tıklandığında açılan menüde tüm aksiyonlar simgeleri ve Türkçe açıklamaları ile sunuldu:
     - 🟢 **Stok Girişi Yap (IN)**
     - 🟠 **Stok Çıkışı Yap (OUT)**
     - 👤 **Personele Zimmetle**
     - ✏️ **Ürün Bilgilerini Düzenle**
     - 🗑️ **Depodan Çıkar (Katalogda Sakla)**

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
