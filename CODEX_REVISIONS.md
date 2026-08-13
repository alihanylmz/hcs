# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini me tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-017] - 2026-08-13 (15:38 +03:00)

### 📌 Başlık
Miktarı 0 Adet Kalan Eski Zimmet Kayıtlarının Veritabanında Otomatik Temizlenmesi & UI Filtresi

### 🎯 Değişiklik & İşlem Özeti
1. **Veritabanı Düzeyinde Otomatik Temizlik (`lib/services/stock_service.dart`):**
   - Zimmet listesi çekilirken (`getOpenPersonnelLoans`), veritabanında `quantity <= 0` kalmış ancak durumu hâlâ `borrowed` kalan tüm geçmiş zimmet kayıtları otomatik olarak `status = 'returned'` ve `closed_at = now()` yapılarak kapatıldı.
   - Sadece `quantity > 0` ve `status = 'borrowed'` olan aktif zimmetler sorgulanmaya başlandı.

2. **Arayüz Düzeyinde Çifte Güvenlik Filtresi (`lib/pages/stock_overview_page.dart`):**
   - Personel zimmet gruplama fonksiyonunda (`_getGroupedLoansMap`) `quantity <= 0` olan ürünler doğrudan filtrelendi. Muhammer veya herhangi bir personelin detay penceresinde 0 adet kalmış ürünlerin (vana vb.) görünmesi engellendi.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

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

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/services/stock_pdf_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
