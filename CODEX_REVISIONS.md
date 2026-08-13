# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

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

## [REV-008] - 2026-08-13 (13:28 +03:00)

### 📌 Başlık
UzalTeklif Birebir Renk Teması Entegrasyonu ve %100 Ekran Genişliğine Yayılan (Full-Width Stretch) DataGrid Tablosu

### 🎯 Değişiklik & İşlem Özeti
1. **UzalTeklif Premium Renk Paleti Entegrasyonu (`lib/theme/app_colors.dart`, `lib/pages/stock_overview_page.dart`):**
   - Birebir `uzalteklif` renk paleti tüm stok modülüne uygulandı:
     - Arka Plan Zemin: `AppColors.sand` (`#F4EFE7` Warm Sand - Teklif zemin rengi).
     - Kartlar & Tablo Yüzeyi: `AppColors.paper` (`#FFFFFCF7` Paper White & `#E4E8ED` Mist Border).
     - Ana Başlıklar & Butonlar: `AppColors.ink` (`#15304A` Deep Navy / Ink).
     - Vurgu & İkincil Aksiyonlar: `AppColors.brass` (`#C98E4B` Warm Gold / Brass Accent).
     - Başarılı / Giriş İşlemleri: `AppColors.mint` (`#4E907A` Sage Mint).

2. **%100 Ekran Genişliğine Yayılan (Full-Width Stretch) DataGrid Tablo Tasarımı:**
   - Tablonun sağ tarafta yarım kalması (`DataTable` genişlik kısıtı) `LayoutBuilder` + `ConstrainedBox(minWidth: constraints.maxWidth)` ile tamamen çözüldü.
   - Tablolar artık ekran ne kadar geniş olursa olsun kartın tüm genişliğini kaplayacak şekilde esner (`width: double.infinity`).
   - Tablo başlığı `AppColors.ink` (`#15304A`) zemin üstüne net beyaz metinlerle kurumsal ERP görünümüne kavuşturuldu.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/theme/app_colors.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
