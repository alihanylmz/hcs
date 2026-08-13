# Codex Revizyon Takip ve Değişiklik Günlüğü (Codex Revision Log)

Bu dosya, yapay zeka ajanları (Antigravity, Codex vb.) tarafından yapılan tüm mimari incelemeleri, kod değişikliklerini ve sistem revizyonlarını tarih ve revizyon numarasıyla kayıt altına alır.

---

## [REV-014] - 2026-08-13 (14:55 +03:00)

### 📌 Başlık
Stok Tablosu 'İşlemler' Hücrelerinin Kurumsal 'Stok İşlemleri ▾' Menü Butonuna Dönüştürülmesi

### 🎯 Değişiklik & İşlem Özeti
1. **Görsel Kalabalığın Temizlenmesi (`lib/pages/stock_overview_page.dart`):**
   - Stok tablosundaki her satırda yan yana sıkışmış duran 3 ayrı buton (`+ Giriş`, `- Çıkış`, `Zimmetle`) kaldırılarak kurumsal **`[Stok İşlemleri ▾]`** butonuna dönüştürüldü.
   - Butona tıklandığında açılan menüde tüm aksiyonlar simgeleri ve Türkçe açıklamaları ile sunuldu:
     - 🟢 **Stok Girişi Yap (IN)**
     - 🟠 **Stok Çıkışı Yap (OUT)**
     - 👤 **Personele Zimmetle**
     - ✏️ **Ürün Bilgilerini Düzenle**
     - 🗑️ **Depodan Çıkar (Katalogda Sakla)**

### 📁 Etkilenen Dosyalar
- `[MODIFY] lib/pages/stock_overview_page.dart`
- `[MODIFY] CODEX_REVISIONS.md`

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
