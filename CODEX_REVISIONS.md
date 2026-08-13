# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

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
