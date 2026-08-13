# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

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
