# TAKIM TABANLI KANBAN SİSTEMİ - GEÇİŞ REHBERİ

## 📋 YAPILAN DEĞİŞİKLİKLER ÖZETİ

### ✅ Kaldırılan Özellikler (Eski Günlük Plan)
- ❌ `DailyActivitiesPage` - Kullanıcı bazlı günlük plan sayfası
- ❌ `ReportsPage` - Günlük rapor sayfası
- ❌ `DailyActivityService` - Günlük aktivite servisi
- ❌ `DailyActivityReportService` - Rapor servisi
- ❌ `DailyActivity` model
- ❌ Tüm daily_activities widget'ları

### ✅ Eklenen Özellikler (Yeni Takım Sistemi)

**Modeller:**
- ✅ `Team` - Takım bilgileri
- ✅ `TeamMember` - Takım üyeleri ve rolleri
- ✅ `Board` - Kanban panoları
- ✅ `Card` - İş kartları
- ✅ `CardEvent` - Kart geçmişi

**Servisler:**
- ✅ `TeamService` - Takım CRUD, üye yönetimi, rol değişimi
- ✅ `BoardService` - Pano yönetimi
- ✅ `CardService` - Kart CRUD, durum/atama değişimi
- ✅ `AnalyticsService` - Takım performans metrikleri

**Sayfalar:**
- ✅ `MyTeamsPage` - Takım listesi (**YENİ GİRİŞ SAYFASI**)
- ✅ `TeamHomePage` - Takım ana sayfa (3 tab)
- ✅ `BoardPage` - Kanban panosu (TODO/DOING/DONE/SENT)
- ✅ `CardDetailPage` - Kart detay ve geçmiş
- ✅ `TeamMembersPage` - Üye yönetimi
- ✅ `TeamAnalyticsPage` - Performans analitikleri

---

## 🚀 KURULUM ADIMLARI

### 1. Supabase Migration (SQL)

Supabase Dashboard → SQL Editor'e gidin ve sırayla çalıştırın:

#### Adım 1: Ana Migration
```sql
-- migration_team_kanban.sql dosyasının tüm içeriğini çalıştırın
```

Bu migration şunları oluşturur:
- ENUM tipleri: `team_role`, `card_status`, `card_event_type`
- Tablolar: `teams`, `team_members`, `boards`, `cards`, `card_events`
- İndeksler (performans)
- RLS politikaları (güvenlik)
- Helper fonksiyonlar

#### Adım 2: Analytics Functions
```sql
-- migration_analytics_functions.sql dosyasının tüm içeriğini çalıştırın
```

Bu migration şunları ekler:
- `calculate_avg_lead_time()` - Ortalama lead time
- `calculate_avg_cycle_time()` - Ortalama cycle time
- `calculate_todo_dwell()` - TODO dwell time
- `calculate_doing_dwell()` - DOING dwell time
- `get_user_completions()` - Kullanıcı performansı

### 2. Profiles Tablosu Kontrolü

Eğer `profiles` tablosu yoksa oluşturun:

```sql
CREATE TABLE IF NOT EXISTS profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    full_name text,
    role text DEFAULT 'technician',
    created_at timestamptz DEFAULT now()
);

-- RLS aktif et
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Herkes profiles'ı okuyabilir (takım üyelerini görmek için)
CREATE POLICY profiles_select_policy ON profiles
    FOR SELECT
    USING (true);

-- Kullanıcı sadece kendi profilini güncelleyebilir
CREATE POLICY profiles_update_policy ON profiles
    FOR UPDATE
    USING (id = auth.uid());
```

### 3. Flutter Uygulama

```bash
# Önce temizlik
flutter clean

# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır
flutter run
```

---

## 🎯 KULLANICI AKIM

### İlk Kullanım
1. **Giriş Yap** → Otomatik olarak `MyTeamsPage` açılır
2. **"Takım Oluştur"** butonuna tıkla
3. Takım adı ve açıklama gir
4. Takım oluşturulur ve sen otomatik **owner** olursun
5. Bir **"Günlük Plan"** panosu otomatik oluşturulur

### Üye Davet Etme
1. Takıma tıkla → **"Üyeler"** tab'ına git
2. **"Davet Et"** butonuna tıkla
3. Üyenin **email adresini** gir (profiles tablosunda kayıtlı olmalı)
4. Üye **member** rolüyle eklenir

### Kanban Kullanımı
1. **"Pano"** tab'ına git
2. **TODO** kolonunda **"Kart Ekle"** butonuna tıkla
3. Başlık, açıklama ve atanan kişi seç
4. Kart oluşturulur ve TODO kolonunda görünür
5. Kartın üç nokta menüsünden durumunu değiştir:
   - TODO → DOING → DONE → SENT

### Analytics Görüntüleme
1. **"Analitik"** tab'ına git
2. Tarih filtresi seç: **Son 7 Gün** / **Son 30 Gün** / **Özel Tarih**
3. Metrikleri görüntüle:
   - **Throughput**: Tamamlanan iş sayısı
   - **Lead Time**: Ortalama tamamlanma süresi
   - **Cycle Time**: Ortalama iş yapma süresi
   - **WIP**: Şu an devam eden işler
   - **Bottleneck**: Darboğaz (TODO mu DOING mi?)
   - **Kullanıcı Performansı**: Kişi bazında istatistikler

---

## 🔐 GÜVENLİK (RLS POLİTİKALARI)

### Takım Yetkileri
- **Owner**: 
  - Takımı silebilir
  - Takım bilgilerini güncelleyebilir
  - Üye rollerini değiştirebilir
  - Üye çıkarabilir
  
- **Admin**:
  - Üye davet edebilir
  - Üye çıkarabilir (owner hariç)
  
- **Member**:
  - Kart ekleyebilir
  - Kart düzenleyebilir
  - Kendi kartlarını silebilir

### RLS Korumaları
- ✅ Kullanıcılar sadece üye oldukları takımları görür
- ✅ Takım dışı kişiler hiçbir veriye erişemez
- ✅ Owner asla çıkarılamaz (RLS policy ile korumalı)
- ✅ Card events değiştirilemez (audit trail)

---

## 📊 ANALİTİK METRİKLER

### 1. Throughput (Verim)
**Ne ölçer?** Belirli sürede tamamlanan iş sayısı
- **DONE**: Biten işler
- **SENT**: Gönderilen işler

### 2. Lead Time (Teslim Süresi)
**Ne ölçer?** Kart oluşturulmasından bitimine kadar geçen süre
- **Formül**: `done_at - created_at`
- **Gösterim**: Saat cinsinden ortalama

### 3. Cycle Time (İş Yapma Süresi)
**Ne ölçer?** İşe başlanmasından bitimine kadar geçen süre
- **Formül**: `done_at - first_doing_at`
- **Gösterim**: Saat cinsinden ortalama

### 4. WIP (Work In Progress)
**Ne ölçer?** Şu an devam eden iş sayısı
- Status = DOING olan kartların sayısı

### 5. Bottleneck (Darboğaz)
**Ne ölçer?** Hangi aşamada daha fazla bekleme olduğu
- **TODO Dwell**: `first_doing_at - created_at` (TODO'da bekleme)
- **DOING Dwell**: `done_at - first_doing_at` (DOING'de bekleme)
- Hangisi yüksekse o darboğazdır

### 6. Kullanıcı Performansı
**Ne ölçer?** Kişi bazında tamamlama istatistikleri
- Tamamlanan iş sayısı
- Ortalama lead time

---

## 🔄 VERİ TAŞIMA (Opsiyonel)

Eğer eski `daily_activities` verisini yeni sisteme taşımak isterseniz:

```sql
-- 1. Önce yedek alın
CREATE TABLE daily_activities_backup AS 
SELECT * FROM daily_activities;

-- 2. Manuel veri taşıma scripti yazabilirsiniz
-- Örnek: Her kullanıcı için bir "Kişisel" takımı oluşturup
-- eski görevleri kart olarak ekleyebilirsiniz

-- 3. Veri taşıma tamamlandıktan sonra eski tabloyu silin
DROP TABLE IF EXISTS daily_activities CASCADE;
```

**Not:** Otomatik migration scripti yazılmadı. Manuel değerlendirme gerekebilir.

---

## 🐛 SORUN GİDERME

### Compile Hatası: "Type not found"
```bash
flutter clean
flutter pub get
flutter run
```

### "User not found" Hatası (Davet)
- Davet edilen kullanıcının `profiles` tablosunda kaydı olmalı
- Email adresi tam eşleşmeli
- Büyük/küçük harf duyarlı değil (otomatik lowercase)

### RLS Policy Hatası
- Kullanıcının takıma üyeliği var mı kontrol edin
- `team_members` tablosunda kayıt olmalı

### Analytics "N/A" Gösteriyor
- Seçili tarih aralığında biten iş yok demektir
- Önce birkaç kartı DONE veya SENT yapın
- Tarihlerin doğru set edildiğini kontrol edin

---

## 📝 SONRAKI ADIMLAR (İsteğe Bağlı)

### Gelecek İyileştirmeler
- [ ] Drag & drop ile kart taşıma
- [ ] Kart filtreleme (atanan, tarih, vb.)
- [ ] Board silme/düzenleme UI'ı
- [ ] Takım silme onay dialog'u
- [ ] Kart renklendirme/etiketleme
- [ ] Bildirim sistemi (kart atandığında)
- [ ] Dashboard widget'ları (tüm takımların özeti)
- [ ] Export (Excel/PDF)
- [ ] Grafik görselleri (chart_fl paketi ile)

---

## 📞 DESTEK

Sorun yaşarsanız:
1. Migration SQL dosyalarını kontrol edin
2. Supabase Table Editor'de tabloların oluşup oluşmadığını kontrol edin
3. RLS politikalarının aktif olduğunu doğrulayın
4. Flutter clean + pub get yapın

---

**Başarılar!** 🎉

Artık uygulamanız tamamen takım tabanlı çalışıyor.
