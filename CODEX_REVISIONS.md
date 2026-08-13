# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-013] - 2026-08-13 (14:34 +03:00)

### 📌 Başlık
Personel Zimmet Ekstresi Modalının Genişletilmesi, Kolon Aralıklarının Mükemmelleştirilmesi ve Kesilme Sorununun Çözülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Modal Genişliği & Kolon Aralıkları (`lib/pages/stock_overview_page.dart`):**
   - Modal diyaloğun maksimum genişliği ekranın %95'ine (1400px) çıkarıldı.
   - `DataTable` varsayılan 56px kolon aralıkları yerine `columnSpacing: 14` ve `horizontalMargin: 12` olarak optimize edildi. Böylece 6 kolon ve tüm aksiyon butonları sağdan kesilmeden tam sığdı.

2. **Kompakt Aksiyon Butonları:**
   - Döküm ekranı aksiyon butonları yer kaplamayacak şık kompakt etiketli butonlara (`[Zimmeti İşle]`, `[Sarf]`, `[Arızalı]`, `[İade]`) dönüştürüldü.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---

## [REV-012] - 2026-08-13 (14:22 +03:00)

### 📌 Başlık
Stok Girişi, Stok Çıkışı, Zimmetle ve Çoklu Seçim Modu Butonlarının Belirgin Etiketli Butonlara Dönüştürülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **İzin Kontrolü Düzeltmesi (`lib/pages/stock_overview_page.dart`):**
   - `_canManageStock` getter'ı profil henüz yüklenme aşamasındayken (`_userProfile == null`) varsayılan olarak `true` dönecek şekilde güncellendi. Böylece tablo aksiyon butonlarının yükleme anında kaybolma sorunu giderildi.

2. **Açık Etiketli Butonlar (`+ Giriş`, `- Çıkış`, `Zimmetle`):**
   - Tabloda daha önce sadece küçük renksiz simgeler olan butonlar, metin etiketli şık `OutlinedButton.icon` butonlarına dönüştürüldü:
     - 🟢 **`+ Giriş`**: Stok Girişi (IN) penceresini açar.
     - 🟠 **`- Çıkış`**: Stok Çıkışı (OUT) penceresini açar.
     - 🔵 **`Zimmetle`**: Personele zimmet verme penceresini açar.

3. **Çoklu Seçim Modu Butonu:**
   - Üst bardaki belirsiz simge yerine **`[☑ Çoklu Seçim (AÇIK)]`** ve **`[☐ Çoklu Seçim]`** durumunu açıkça gösteren buton yerleştirildi.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
