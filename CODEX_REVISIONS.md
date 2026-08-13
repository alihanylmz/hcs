# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini me tarih me revizyon numarasıyla kayıt altına alır.

---

## [REV-018] - 2026-08-13 (15:48 +03:00)

### 📌 Başlık
Zimmet Kapatıldığında Veritabanındaki 'quantity' Değerinin 0 Yapılması ve Honeywell Vana Zimmet Kalıntısının Tamamen Temizlenmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Hata Kök Neden Tespiti (`lib/services/stock_service.dart`):**
   - Zimmetlenen bir ürün (örn. Honeywell Vana) arızalıya ayırıp kapatıldığında, veritabanında `status = 'returned'` yapılsa dahi `quantity` sütunu `1` olarak kalıyordu. Bu durum eski zimmet kayıtlarının arayüzde "0 adet" veya "1 adet" şeklinde asılı kalmasına yol açıyordu.

2. **Uygulanan Çözüm (`processPersonnelLoanResolution` & `getOpenPersonnelLoans`):**
   - Zimmet kapatıldığı an (`remainingQty <= 0`) Supabase `product_stock_loans` tablosunda `quantity` değeri doğrudan `0` olarak güncellendi.
   - Sayfa yüklendiğinde çalışacak otomatik veritabanı sorgusuyla veritabanında asılı kalmış tüm sıfır zimmet kayıtlarının miktarları `0` yapıldı ve kapatıldı. Honeywell Vana vb. kapalı ürünler Muhammer'in zimmet listesinden kalıcı olarak silindi.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-017] - 2026-08-13 (15:38 +03:00)

### 📌 Başlık
Miktarı 0 Adet Kalan Eski Zimmet Kayıtlarının Veritabanında Otomatik Temizlenmesi & UI Filtresi

### 🎯 Değişiklik & İşlem Özeti
1. **Veritabanı Düzeyinde Otomatik Temizlik (`lib/services/stock_service.dart`):**
   - Zimmet listesi çekilirken (`getOpenPersonnelLoans`), veritabanında `quantity <= 0` kalmış ancak durumu hâlâ `borrowed` kalan tüm geçmiş zimmet kayıtları otomatik olarak `status = 'returned'` ve `closed_at = now()` yapılarak kapatıldı.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
