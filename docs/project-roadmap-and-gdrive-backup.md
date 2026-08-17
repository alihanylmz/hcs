# 🚀 Uzal Teknik ERP - Proje Durumu & Google Drive Otomatik PDF Yedekleme Rehberi

> **AI AJANLARI VE GELİŞTİRİCİLER İÇİN ZORUNLU OKUMA DOKÜMANIDIR**  
> Bu dosya, projede ne durumda olduğumuzu, tamamlanan modülleri, eksikleri ve ileride aktif edilecek **Google Drive Otomatik PDF Yedekleme Sisteminin** mimarisini açıklar.

---

## 📌 1. PROJENİN MEVCUT DURUMU VE MİMARİSİ

Proje, **Uzal Teknik Mühendislik** için geliştirilmiş iki ana iş modülünden oluşan entegre bir ERP platformudur:

### 📄 Modül 1: Uzal Teklif & Keşif Sistemi (`uzalteklif`)
- **Landing Page / Giriş Sayfası:** `MyWorkspacePage` (Personel Çalışma Masası / Masam).
- **Keşif ve Nokta Listesi:** Keşif projeleri, hazır hızlı çip şablonları, personele özel kalıcı ⭐ favori ürün eşleştirici.
- **Teklif Hazırlama ve Gönderim:** Dinamik teklif fiyatlandırması, sade e-posta gönderimi ve **💬 Tek Tıkla WhatsApp İle Gönderim**.
- **Cari Yönetimi:** Müşteri/Cari kartları, yetkili yönetici vs. personel görünüm kısıtlamaları.

### 🛠️ Modül 2: İş Takip & Atölye Operasyonları (`istakip_app`)
- **Saha İş Emirleri:** Servis ve saha takip kartları.
- **Atölye İmalat & Pano Reçeteleri:** Gelişmiş Atölye İmalat İş Emri formu (`_WorkshopDispatchDialog`), imalat türü, usta seçimi, teknik detaylar ve 6 adımlı kalite kontrol çeklisti.
- **Akıcı Modül Geçişi (App Switcher):** İki modül arasında şifre/oturum kopmadan `🛠️ İş Takip` ve `📄 Uzal Teklif` geçiş düğmeleri.

---

## ☁️ 2. GOOGLE DRIVE OTOMATİK PDF YEDEKLEME SİSTEMİ (BEKLEYEN GÖREV)

### 🎯 Amaç:
Supabase veritabanını veya Storage alanını kazaen veya kota olarak **şişirmeden**, üretilen tüm Teklifleri, Saha İş Emirlerini ve Atölye İmalat Reçetelerini otomatik olarak **Google Drive** üzerinde tarihli PDF klasörleri halinde arşivlemek.

### 📂 Hedef Google Drive Klasör Yapısı:
```text
📁 Uzal Teknik Otomatik PDF Yedekleri /
  ├── 📁 YYYY-MM (Örn: 2026-08) /
  │    ├── 📁 Teklifler (PDF) /
  │    │    ├── TEK-2026-0012_Marmara_Endustri.pdf
  │    │    └── TEK-2026-0013_Aselsan_Pano.pdf
  │    ├── 📁 Saha_Is_Emirleri (PDF) /
  │    │    └── IS-2026-0089_AHU_Servis.pdf
  │    └── 📁 Atolye_Imalat_Receteleri (PDF) /
  │         └── ATOLYE-0045_Pano_Imalat.pdf
```

### ⚙️ Uygulama Adımları (İşleme Alındığında Yapılacaklar):

1. **Google Cloud Service Account Kurulumu:**
   - Google Cloud Console üzerinden ücretsiz bir Service Account oluşturulacak (`backup-service@uzal-teknik.iam.gserviceaccount.com`).
   - Google Drive API etkinleştirilecek.
   - Google Drive'da açılan `Uzal Teknik Yedekler` klasörüne bu service account e-postasına "Yazma/Yükleme" yetkisi verilecek.

2. **Supabase Edge Function (`supabase/functions/backup-to-drive`):**
   - PDF oluşturma veya hazır PDF çıktısını alma.
   - Google Drive Resumable Upload API kullanarak Supabase Storage'ı şişirmeden doğrudan Google Drive'a `POST/PUT` ile aktarım.

3. **Tetiklenme Noktaları:**
   - **Anlık:** Teklif durumunda `Gönderildi / Onaylandı` olduğunda veya İş emri atölyeye sevk edildiğinde.
   - **Zamanlanmış (Cron Job):** Her gece 02:00'de günün üretilen evraklarının PDF yedeğini alma.

---

## 📋 3. PROJEDE NE EKSİK? (GELİŞTİRME YOL HARİTASI)

1. ⏳ **Google Drive Otomatik PDF Arşivleme Entegrasyonu** *(Yukarıdaki rehbere göre kurulacak)*.
2. ⏳ **Atölye Ustası Fotoğraflı İş Bitirme Onayı:** Atölye imalat kartında ustanın tamamlanan panonun fotoğrafını yükleyerek kalite kontrolü tamamlaması.
3. ⏳ **Cari Hesap Ekstresi & Genel Raporlama:** Müşteriye kesilen teklif ve iş emirlerinin toplu PDF ekstresi.
4. ⏳ **İş Emri Kullanılan Malzeme & Parça Profesyonel Entegrasyonu:**
   - `ticket_parts` tablosunun seri numarası (`serial_number`), faturalandırma/garanti durumu (`is_billable`, `warranty`), birim fiyat/maliyet ve kaynak türü (`source_type`: Depo / Teknisyen Zimmeti) ile genişletilmesi.
   - `TicketDetailPage` (İş Emri Detay) ekranına doğrudan tek tıkla **"Parça / Malzeme Ekle"** modalı (`Kendi Zimmetimden Kullan` veya `Depo Stoğundan Kullan`).
   - Personel zimmetindeki seri numaralı cihazlar (`product_stock_loans`) ile iş emrinin çift yönlü senkronizasyonu (sarf edildiğinde zimmetten otomatik düşme).
   - Resmi Müşteri Servis Formu ve Onay PDF çıktısına (`TicketPdfService`) kullanılan malzemeler / yedek parçalar tablosunun eklenmesi.

---

> **NOT:** Bu doküman kullanıcının talebi üzerine oluşturulmuştur ve gelecekteki tüm AI sohbetlerinde referans doküman olarak kabul edilecektir.

