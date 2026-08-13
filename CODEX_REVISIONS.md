# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

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

## [REV-011] - 2026-08-13 (14:20 +03:00)

### 📌 Başlık
Personel Zimmet Ekstre Penceresinin Tam Genişlik Yapılması, Başlık İyileştirmesi ve Hızlı Sarf / Arızalı / İade Aksiyon Butonları

### 🎯 Değişiklik & İşlem Özeti
1. **Başlık İyileştirmesi (`lib/pages/stock_overview_page.dart`):**
   - Tablo başlığındaki `(Cari Hesap)` ifadesi kaldırıldı, sade `Teknik Personel` olarak güncellendi.

2. **Duyarlı ve Geniş Ekstre Penceresi:**
   - Personel zimmet detay modalının genişliği ekranın %90'ına (max 1200px) çıkarıldı.
   - Modal içerisindeki DataGrid `LayoutBuilder` + `ConstrainedBox(minWidth: constraints.maxWidth)` ile tamamen kaplayacak biçimde esnetildi. Kesilme/yarım görünme sorunu tamamen giderildi.

3. **Hızlı Zimmet İşlem Butonları (Sarf Edildi / Arızalıya Ayır / İade):**
   - Zimmet döküm tablosunda her ürün satırına doğrudan hızlı işlem butonları eklendi:
     - ⚡ **`Sarf Et`**: Zimmetli miktarı doğrudan projede kullanıldı olarak sarf eder.
     - 🛠️ **`Arızalı`**: Ürünü doğrudan arızalı stoğa (RMA) kaydırır.
     - ↩️ **`İade`**: Ürünü depodaki sağlam stoğa iade eder.
     - ⚙️ **`Zimmeti İşle / Kapat`**: Özelleştirilebilir miktar girişi modallarını açar.

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

---
