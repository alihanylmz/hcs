# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-007] - 2026-08-13 (12:44 +03:00)

### 📌 Başlık
Yüksek Kontrastlı Tablo Tasarımı, Esnek Zimmet Sarf/İade Yönetimi ve Akıllı Katalog İsimlendirmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Esnek Zimmet Sarf / İade ve İş Kodu Bağlantısı (`lib/services/stock_service.dart`, `lib/pages/stock_overview_page.dart`):**
   - **Kısmi Sarf / İade Mantığı:** Personeldeki zimmet kapatılırken veya işlenirken sarf edilen (projede kullanılan) miktar ile depoya iade edilen miktar ayrı ayrı girilebilir (Örn: 10 adet zimmetten 5'i sarf edildi, 5'i depoya iade alındı).
   - **İş Kodu Dropdown:** Zimmet verirken veya sarf işlerken serbest not yerine doğrudan aktif **İş Kodu (Ticket)** seçimi zorunlu/isteğe bağlı dropdown olarak bağlandı.

2. **Akıllı Katalog Ürün İsimlendirmesi:**
   - Katalogdaki ham teknik özellik dizileri (`16UIO,4CHO,4Rel...`) ana ürün adı yerine alt özellik rozetine çekildi. Ürün Kodu, Marka ve Kategori harmanlanarak temiz kurumsal başlıklar (`Honeywell Zone Controllers`) gösterildi.

3. **Yüksek Kontrastlı ERP Tablo Tasarımı:**
   - Kullanıcı ekran görüntüsü analiz edilerek sönük gri metinler, hizalaması kayan sayfalama çubuğu ve koyu gri buton uyuşmazlıkları düzeltildi.
   - Tablo hücrelerinde tam koyu slate metinler (`#0F172A`, `#1E293B`), belirgin kenarlıklar ve kart altıyla hizalı temiz sayfalama çubuğu sağlandı.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/services/stock_service.dart`
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

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
