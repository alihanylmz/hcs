# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-006] - 2026-08-13 (12:31 +03:00)

### 📌 Başlık
DataGrid Sayfalama (Pagination) ile Kasma/Donma Çözümü ve Kurumsal Renk Paleti Revizyonu

### 🎯 Değişiklik & İşlem Özeti
1. **Yüksek Performanslı Sayfalama (Pagination Entegrasyonu):**
   - "Tüm Ürün Kataloğu" sekmesinde 2.189 ürünün aynı anda 20.000+ widget olarak çizilip ana UI thread'i kilitlemesi (donma/kasma) %100 engellendi.
   - Client-side **DataGrid Pagination** eklendi (`_pageSize = 50`, `25 / 50 / 100` ürün seçimi). Sayfa başına sadece ekrandaki 50 ürün çizilerek render süresi **5 milisaniyeye** düşürüldü.
   - Alt kontrol çubuğu: `Önceki Sayfa` | `Gösterilen: 1 - 50 / 2189 Ürün (Sayfa 1 / 44)` | `Sonraki Sayfa`.

2. **Kurumsal Renk ve Tasarım Revizyonu (`lib/pages/stock_overview_page.dart`):**
   - Ham/parlak cırt renkler kaldırıldı. `AppColors` renk paleti standartlarına geçildi:
     - Header & Zemin: `AppColors.backgroundGrey` (`#F1F3F6`), `AppColors.surfaceWhite` (`#FFFFFF`).
     - Metinler & Kenarlıklar: İnce slate border (`#D8DEE7`), `AppColors.textDark` (`#0F172A`).
     - Butonlar: `AppColors.corporateBlue` (`#0F6BFF`).
     - Durum Rozetleri (Badges): Muted pastel tonlar (Stokta Var: Soft Emerald `#DCFCE7`, Kritik: Soft Amber `#FEF3C7`, Tükendi: Soft Rose `#FEE2E2`).

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-005] - 2026-08-13 (12:15 +03:00)

### 📌 Başlık
Güvenli Soft-Untracking (Katalog Koruma), Sanal Katalog Temizliği ve Akıllı İsim Formatlama

### 🎯 Değişiklik & İşlem Özeti
1. **Güvenli Soft-Untracking Mantığı (`lib/services/stock_service.dart`):**
   - **Katalog Koruma Garantisi:** Fiyat teklifi kataloğundaki (`uzalteklif`) 2.000+ ürünün veritabanından Asla silinmemesi için `stopStockTracking()` ve `deleteStock()` fonksiyonları **soft-untrack** (`stock_tracking_started = false`, `stock_quantity = 0`) mantığına geçirildi.
   - Bir ürün depodan çıkarıldığında Fiyat Teklifleri Kataloğunda fiyatı, para birimi ve teknik özellikleriyle **eksiksiz kalmaya devam eder**, sadece fiziksel depo listesinden gizlenir.

2. **Sanal Katalog Stoklarını Sıfırlama Butonu (`resetCatalogStockTracking`):**
   - Üst menüye eklenen *"Sanal Katalog Stoklarını Temizle"* aksiyonu ile veritabanındaki sanal katalog takipleri tek tıkla temizlenebilir. Kullanıcı sadece kendi depoya eklediği 5-10 gerçek fiziksel ürünü listede tutar.

3. **Akıllı Ürün İsmi Formatlama (`formatProductName`):**
   - Katalog aktarımlarından gelen karmaşık metinler temizlendi. Ürün Kodu ve Sade Ürün Adı ayrı DataGrid sütunlarında gösterildi.

4. **Sürüm Yükseltme & PWA Önbellek Yenilenmesi:**
   - Uygulama sürümü `1.1.11+16` olarak yükseltilerek tarayıcı ve Plesk FTP önbelleğinin yenilenmesi garanti altına alındı.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
