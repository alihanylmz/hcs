# ⚡ HIZLI ÇÖZÜM: Team Members Hatası

## Muhtemel Sebepler ve Çözümler

### 1️⃣ EN MUHTEMEL: Migration Uygulanmamış ❗

**Sorun:** `team_members` tablosu henüz oluşturulmamış

**Çözüm:** Supabase'e migration SQL'lerini yükleyin:

1. **Supabase Dashboard'a gidin:**
   - https://supabase.com/dashboard
   - Projenizi seçin
   - SQL Editor'e tıklayın

2. **Migration dosyalarını çalıştırın:**

#### ✅ Adım 1: Ana Migration
```sql
-- migration_team_kanban.sql dosyasını açın
-- Tüm içeriği kopyalayın
-- Supabase SQL Editor'e yapıştırın
-- "RUN" butonuna tıklayın
```

#### ✅ Adım 2: Analytics Functions
```sql
-- migration_analytics_functions.sql dosyasını açın
-- Tüm içeriği kopyalayın
-- Supabase SQL Editor'e yapıştırın
-- "RUN" butonuna tıklayın
```

---

### 2️⃣ ALTERNATIF: Foreign Key Hatası

**Sorun:** `profiles` tablosu foreign key constraint

**Çözüm:** Önce profiles tablosunu oluşturun:

```sql
-- Supabase SQL Editor'de çalıştırın:
CREATE TABLE IF NOT EXISTS profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email text UNIQUE NOT NULL,
    full_name text,
    role text DEFAULT 'technician',
    created_at timestamptz DEFAULT now()
);

-- RLS aktif et
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Herkes okuyabilir
CREATE POLICY profiles_select_policy ON profiles
    FOR SELECT USING (true);

-- Kullanıcı sadece kendini güncelleyebilir
CREATE POLICY profiles_update_policy ON profiles
    FOR UPDATE USING (id = auth.uid());
```

**Sonra migration'ı tekrar çalıştırın.**

---

### 3️⃣ RLS Policy Hatası

**Sorun:** Row Level Security INSERT policy çalışmıyor

**Geçici Çözüm (sadece test için):**

```sql
-- SADECE TEST İÇİN - Production'da kullanmayın!
ALTER TABLE team_members DISABLE ROW LEVEL SECURITY;
```

**Kalıcı Çözüm:** Migration dosyasındaki policy'leri kontrol edin:

```sql
-- team_members INSERT policy tekrar uygulayın:
DROP POLICY IF EXISTS team_members_insert_policy ON team_members;
CREATE POLICY team_members_insert_policy ON team_members
    FOR INSERT
    WITH CHECK (
        get_team_role(team_id, auth.uid()) IN ('owner', 'admin')
        AND invited_by = auth.uid()
    );
```

---

### 4️⃣ Helper Function Hatası

**Sorun:** `get_team_role()` fonksiyonu yok

**Çözüm:** Migration'da helper fonksiyonlar var mı kontrol edin:

```sql
-- Supabase → Database → Functions'da şunlar olmalı:
-- ✅ is_team_member()
-- ✅ get_team_role()
```

Yoksa `migration_team_kanban.sql` dosyasını tekrar çalıştırın.

---

## 🔍 HATA AYIKLAMA ADIMLARI

### Adım 1: Tabloları Kontrol Edin

**Supabase → Table Editor:**
- ✅ `teams` tablosu var mı?
- ✅ `team_members` tablosu var mı?
- ✅ `boards` tablosu var mı?
- ✅ `cards` tablosu var mı?

### Adım 2: RLS Kontrolü

**Supabase → Database → Tables:**
- Her tablo için **"RLS enabled"** işaretli olmalı
- **Policies** sekmesinde politikalar görünmeli

### Adım 3: Tam Hata Mesajını Görün

**Flutter DevTools Console:**
1. Uygulamayı çalıştırın
2. "Takım Oluştur" butonuna tıklayın
3. Browser Console'da (F12) tam hata mesajını görün
4. Bana tam hata mesajını gönderin

---

## 🚀 HIZLI TEST

Migration uygulandıktan sonra test edin:

```sql
-- Supabase SQL Editor'de:
-- 1. Kendi user_id'nizi bulun
SELECT id, email FROM auth.users LIMIT 5;

-- 2. Manuel takım oluşturun (YOUR_USER_ID ile değiştirin)
INSERT INTO teams (name, created_by) 
VALUES ('Test Takımı', 'YOUR_USER_ID')
RETURNING *;

-- 3. Yukarıdaki team id'yi kullanarak kendinizi ekleyin
INSERT INTO team_members (team_id, user_id, role, invited_by)
VALUES ('TEAM_ID', 'YOUR_USER_ID', 'owner', 'YOUR_USER_ID')
RETURNING *;

-- ✅ Başarılıysa migration doğru uygulanmış
-- ❌ Hata alırsanız migration eksik
```

---

## 📝 TAM HATA MESAJINI GÖNDERIN

Lütfen tam hata mesajını paylaşın:
- Browser Console (F12) hatası
- Ya da uygulamada gösterilen hata mesajı
- Ya da terminal'deki tam log

Bu bilgiyle daha spesifik çözüm sunabilirim!
