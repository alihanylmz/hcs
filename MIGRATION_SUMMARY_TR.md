# 🎯 TAKIM KANBAN SİSTEMİ - KURULUM TAMAMLANDI

## ✅ YAPILAN DEĞİŞİKLİKLER

### 🗑️ Kaldırılan Eski Sistem
- ❌ **DailyActivitiesPage** - Kullanıcı bazlı günlük plan sayfası
- ❌ **ReportsPage** - Eski rapor sayfası
- ❌ **DailyActivityService** - Günlük aktivite servisi
- ❌ **DailyActivityReportService** - Rapor servisi
- ❌ **daily_activity** model ve tüm widget'ları

### ✨ Eklenen Yeni Sistem

**📁 Yeni Modeller:**
```
lib/models/
├── team.dart          → Team, TeamMember, TeamRole
├── board.dart         → Board
├── kanban_card.dart   → KanbanCard, CardStatus
└── card_event.dart    → CardEvent, CardEventType
```

**⚙️ Yeni Servisler:**
```
lib/services/
├── team_service.dart      → Takım yönetimi
├── board_service.dart     → Pano yönetimi  
├── card_service.dart      → Kart yönetimi
└── analytics_service.dart → Performans metrikleri
```

**🎨 Yeni Sayfalar:**
```
lib/pages/
├── my_teams_page.dart       → Takımlarım (GİRİŞ SAYFASI ⭐)
├── team_home_page.dart      → Takım ana sayfa (3 tab)
├── board_page.dart          → Kanban panosu
├── card_detail_page.dart    → Kart detay
├── team_members_page.dart   → Üye yönetimi
└── team_analytics_page.dart → Analitikler
```

**📊 SQL Migration Dosyaları:**
```
├── migration_team_kanban.sql         → Ana tablolar ve RLS
└── migration_analytics_functions.sql → Analitik RPC fonksiyonları
```

---

## 🚀 HEMEN ŞİMDİ YAPIN

### 1️⃣ Supabase Migration Uygula

**Supabase Dashboard'a gidin:**
https://supabase.com/dashboard → Projeniz → SQL Editor

**Sırasıyla çalıştırın:**

#### ✅ Adım 1: Ana Migration
```sql
-- migration_team_kanban.sql dosyasının tamamını kopyalayıp çalıştırın
```

Bu şunları oluşturur:
- ✅ ENUM'lar: `team_role`, `card_status`, `card_event_type`
- ✅ Tablolar: `teams`, `team_members`, `boards`, `cards`, `card_events`
- ✅ İndeksler (performans)
- ✅ RLS politikaları (güvenlik)
- ✅ Helper fonksiyonlar

#### ✅ Adım 2: Analytics Functions
```sql
-- migration_analytics_functions.sql dosyasının tamamını kopyalayıp çalıştırın
```

Bu şunları ekler:
- ✅ `calculate_avg_lead_time()` - Ortalama teslim süresi
- ✅ `calculate_avg_cycle_time()` - Ortalama iş yapma süresi
- ✅ `calculate_todo_dwell()` - TODO bekleme süresi
- ✅ `calculate_doing_dwell()` - DOING bekleme süresi
- ✅ `get_user_completions()` - Kullanıcı performansı

### 2️⃣ Profiles Tablosu Kontrolü

Eğer `profiles` tablosu yoksa oluşturun:

```sql
CREATE TABLE IF NOT EXISTS profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    full_name text,
    role text DEFAULT 'technician',
    created_at timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select_policy ON profiles
    FOR SELECT USING (true);

CREATE POLICY profiles_update_policy ON profiles
    FOR UPDATE USING (id = auth.uid());
```

### 3️⃣ Flutter Uygulamayı Çalıştırın

```powershell
# Zaten yapıldı:
# flutter clean
# flutter pub get

# Şimdi çalıştırın:
flutter run
```

---

## 🎮 NASIL KULLANILIR

### İlk Takımı Oluşturma
1. ✅ Uygulamayı açın → **"Takımlarım"** sayfası açılır
2. ✅ Sağ üstteki **+** butonuna tıklayın
3. ✅ Takım adı girin (örn: "Satış Ekibi")
4. ✅ **"Oluştur"** butonuna tıklayın
5. ✅ Otomatik olarak **owner** olursunuz
6. ✅ **"Günlük Plan"** adında bir pano otomatik oluşturulur

### Üye Davet Etme
1. ✅ Takıma tıklayın → **"Üyeler"** tab'ına geçin
2. ✅ **"Davet Et"** butonuna tıklayın
3. ✅ Üyenin **email adresini** girin (sistem kayıtlı olmalı)
4. ✅ Üye **member** rolüyle eklenir

### Kart Ekleme ve Yönetme
1. ✅ **"Pano"** tab'ına geçin
2. ✅ **TODO** kolonunda **"Kart Ekle"** butonuna tıklayın
3. ✅ Başlık, açıklama ve atanan kişi girin
4. ✅ Kart TODO kolonunda görünür
5. ✅ Kartın **⋮** menüsünden durumunu değiştirin:
   - TODO → DOING → DONE → SENT
6. ✅ Karta tıklayarak detayları görün ve düzenleyin

### Analitikleri Görüntüleme
1. ✅ **"Analitik"** tab'ına geçin
2. ✅ Tarih filtresi seçin: **Son 7 Gün** / **Son 30 Gün** / **Özel Tarih**
3. ✅ Metrikleri inceleyin:
   - **Throughput**: Tamamlanan iş sayısı
   - **Lead Time**: Ortalama teslim süresi (saat)
   - **Cycle Time**: Ortalama iş yapma süresi (saat)
   - **WIP**: Şu an devam eden işler
   - **Bottleneck**: Darboğaz (TODO/DOING)
   - **Kullanıcı Performansı**: Kişi bazında istatistikler

---

## 📊 ANALİTİK METRİKLER AÇIKLAMA

### 1. Throughput (Verim)
**Ölçüm:** Belirli sürede tamamlanan iş sayısı
- **DONE**: Bitirilen kartlar
- **SENT**: Gönderilen kartlar

### 2. Lead Time (Teslim Süresi)
**Ölçüm:** Kart oluşturulmasından bitimine kadar geçen toplam süre
- **Formül:** `done_at - created_at`
- **Gösterim:** Saat cinsinden ortalama
- **Örnek:** 48.5s = Ortalama 2 gün

### 3. Cycle Time (İş Yapma Süresi)
**Ölçüm:** İşe başlanmasından bitimine kadar geçen süre
- **Formül:** `done_at - first_doing_at`
- **Gösterim:** Saat cinsinden ortalama
- **Örnek:** 8.2s = Ortalama 8 saat

### 4. WIP (Work In Progress)
**Ölçüm:** Şu an **DOING** durumundaki kartların sayısı

### 5. Bottleneck (Darboğaz)
**Ölçüm:** Hangi aşamada daha fazla bekleme olduğu
- **TODO Dwell**: TODO'da ortalama bekleme süresi
- **DOING Dwell**: DOING'de ortalama bekleme süresi
- **Sonuç**: Hangisi yüksekse o darboğazdır

### 6. Kullanıcı Performansı
**Ölçüm:** Kişi bazında tamamlama istatistikleri
- Tamamlanan iş sayısı
- Ortalama lead time

---

## 🔐 GÜVENLİK (RLS)

### Takım Rolleri ve Yetkileri

| Yetki | Owner | Admin | Member |
|-------|-------|-------|--------|
| Takım silme | ✅ | ❌ | ❌ |
| Takım bilgilerini güncelleme | ✅ | ❌ | ❌ |
| Üye davet etme | ✅ | ✅ | ❌ |
| Rol değiştirme | ✅ | ❌ | ❌ |
| Üye çıkarma | ✅ | ✅ (owner hariç) | ❌ |
| Kart ekleme | ✅ | ✅ | ✅ |
| Kart düzenleme | ✅ | ✅ | ✅ |
| Kart silme | ✅ | ✅ | ✅ (kendi kartı) |

### RLS Korumaları
- ✅ Kullanıcılar **sadece** üye oldukları takımları görür
- ✅ Takım dışı kişiler hiçbir veriye erişemez
- ✅ Owner asla çıkarılamaz (RLS ile korumalı)
- ✅ Card events değiştirilemez (audit trail)

---

## 📱 UYGULAMA AKIŞI

```
GİRİŞ → MyTeamsPage (Takımlarım)
           ↓
        Takım Seç
           ↓
      TeamHomePage
           ↓
    ┌──────┴──────┬──────────┐
    │             │          │
  Pano        Analitik    Üyeler
    │             │          │
Kanban      Metrikler    Davet Et
 Board                   Rol Değiştir
```

---

## ⚠️ ÖNEMLİ NOTLAR

### 1. Eski Veriler
- Eski `daily_activities` tablosu **korundu**
- Eğer silmek isterseniz:
  ```sql
  DROP TABLE IF EXISTS daily_activities CASCADE;
  ```

### 2. İlk Test Takımı
Migration sonrası SQL ile test takımı oluşturabilirsiniz:

```sql
-- Kendi user_id'nizi bulun
SELECT id, email FROM auth.users WHERE email = 'sizin@email.com';

-- Takım oluştur (YOUR_USER_ID ile değiştirin)
INSERT INTO teams (name, description, created_by) 
VALUES ('Test Takımı', 'İlk takım', 'YOUR_USER_ID')
RETURNING id;

-- Kendinizi owner yapın (TEAM_ID ile değiştirin)
INSERT INTO team_members (team_id, user_id, role, invited_by)
VALUES ('TEAM_ID', 'YOUR_USER_ID', 'owner', 'YOUR_USER_ID');

-- Board oluştur
INSERT INTO boards (team_id, name)
VALUES ('TEAM_ID', 'Günlük Plan');
```

### 3. Navigasyon
- ✅ **Ana sayfa değişti:** Login sonrası → `MyTeamsPage`
- ✅ **Drawer menü güncellendi:** "Günlük Planım" → "Takımlarım"
- ✅ **Sidebar güncellendi:** Aynı şekilde

---

## 🐛 SORUN GİDERME

### "User not found" Hatası
**Sebep:** Davet edilen kişi `profiles` tablosunda yok
**Çözüm:** Önce kullanıcının sisteme kayıt olması gerekiyor

### "Permission denied" Hatası
**Sebep:** RLS politikaları aktif değil
**Çözüm:** Migration'ı tekrar çalıştırın

### Analytics "N/A" Gösteriyor
**Sebep:** Seçili tarih aralığında veri yok
**Çözüm:** Önce birkaç kart oluşturup DONE/SENT yapın

---

## 🎉 BAŞARILI!

Artık uygulamanız **tamamen takım tabanlı** çalışıyor:
- ✅ Takım oluşturma
- ✅ Üye yönetimi (email ile davet)
- ✅ Kanban panosu (TODO/DOING/DONE/SENT)
- ✅ Kart detay ve geçmiş
- ✅ Takım performans analitikleri
- ✅ Rol tabanlı yetkilendirme

**Önemli:** Migration SQL'lerini Supabase'e uygulamayı unutmayın!

Başarılar! 🚀
