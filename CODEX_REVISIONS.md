# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-010] - 2026-08-13 (14:10 +03:00)

### 📌 Başlık
Personel Bazlı Zimmet Yönetimi (Cari Hesap Mantığı & Ekstre Dökümü)

### 🎯 Değişiklik & İşlem Özeti
1. **Personel Bazlı Zimmet Mimarisi ("Cari Mantığı"):**
   - Zimmetler tablosu ham satır bazlı görünümden çıkartılıp **Personel Cari Hesap Kartları** mantığına dönüştürüldü.
   - Ana listede teknik personel isimleri (`Muhammer Yılmaz`, `Ali Han` vb.), üzerlerindeki zimmetli ürün çeşit sayısı, toplam malzeme adedi ve son zimmet tarihi özet tablo olarak gösterildi.

2. **Personel Zimmet Ekstresi & Detay Modalı:**
   - Personel satırındaki **"Zimmet Dökümü & İşle"** butonuna basıldığında o personele ait tüm ürünlerin listelendiği özel ekstre penceresi açılır.
   - Ekstre içerisinden kalem kalem zimmet kapatılabilir/sarf/arızalı işlenebilir veya doğrudan o personel için yeni zimmet kaydı açılabilir.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-009] - 2026-08-13 (14:04 +03:00)

### 📌 Başlık
Arızalı Ürün Yönetimi (RMA & Servis Takibi) ve Zimmetten Arızalı Ayrıştırma Süreci Entegrasyonu

### 🎯 Değişiklik & İşlem Özeti
1. **Zimmet Kapatırken Arızalı Ayrıştırma (`lib/pages/stock_overview_page.dart`, `lib/services/stock_service.dart`):**
   - Zimmet kapatma modalı 3 girdili yapıya yükseltildi: **Sarf Edilen**, **Depoya İade**, **Arızalı Ayrılan** (Örn: 10 zimmetten 5 sarf, 3 iade, 2 arızalı).
   - Arızalı olarak bildirilen ürünler otomatik olarak **"Arızalı Ürünler (RMA)"** takip listesine kaydırılır ve durumları `Arızalı Depoda (Bekliyor)` olarak işaretlenir.

2. **Arızalı Ürünler (RMA) Takip Sekmesi & Servis/Kargo Süreçleri:**
   - Üst menüye yeni **"Arızalı Ürünler (RMA)"** DataGrid sekmesi eklendi.
   - Arızalı ürünlerin süreç hareketleri tanımlandı:
     - 🚚 `Tedarikçiye / Servise Kargolandı` (Firma Adı & Kargo Takip Kodu kaydı).
     - ✅ `Tamir Edildi` (Otomatik olarak depodaki sağlam stok miktarına tekrar eklenir).
     - 🔄 `Yenisi Geldi` (Otomatik olarak depodaki sağlam stok miktarına tekrar eklenir).
     - ❌ `Hurdaya Ayrıldı` (Kullanılamaz çöp olarak arşivlenir).

3. **Veritabanı Migration:**
   - `defective_products` tablosu ve yetki politikaları eklendi (`uzalteklif/supabase/migrations/20260813_defective_products.sql`).

### 📁 Etkilenen Dosyalar
- `[NEW] uzalteklif/supabase/migrations/20260813_defective_products.sql`
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
