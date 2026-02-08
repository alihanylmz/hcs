# 🔧 KAPSAMLI FİX TALİMATI

## 🎯 Sorunlar ve Çözüm

Karşılaşılan sorunlar:
1. ❌ Kart görünümleri bozuldu
2. ❌ Bildirimler gelmiyor
3. ❌ Kart eklerken atama yapamıyorum (göstermiyor)
4. ❌ Takım sayfasındaki her şey bozuldu

**Neden?** Migration dosyaları arasında çakışmalar ve eksik yapılandırmalar var.

## ⚡ HIZLI ÇÖZÜM (5 Dakika)

### 1️⃣ SQL Script'i Çalıştır

1. **Supabase Dashboard** açın: https://supabase.com/dashboard
2. **SQL Editor** sekmesine gidin
3. `fix_all_issues.sql` dosyasını açın ve tüm içeriğini kopyalayın
4. SQL Editor'e yapıştırın
5. **RUN** butonuna basın
6. ✅ "Success" mesajı görmelisiniz

### 2️⃣ Flutter Uygulamayı Yeniden Başlatın

```bash
# Terminalde çalıştırın:
flutter clean
flutter pub get
flutter run
```

### 3️⃣ Test Edin

1. **Takım Oluşturun**
   - Takımlarım sayfasına gidin
   - "Yeni Takım" butonuna basın
   - Bir isim girin ve oluşturun

2. **Kart Ekleyin**
   - Takıma tıklayın
   - "Kart Ekle" butonuna basın
   - ✅ Dropdown'da "Atanan Kişi" seçeneği görünmeli
   - ✅ En azından siz (takım sahibi) listede olmalısınız

3. **Bildirim Kontrolü**
   - Başka bir kullanıcı ekleyin (Settings → Kullanıcılar)
   - O kullanıcıya bir kart atayın
   - ✅ Bildirim gitmeli

## 🔍 SORUN DEVAM EDİYORSA

### Debug Modu ile Çalıştırın

```bash
flutter run --verbose
```

Console'da şu log'ları arayın:

```
🔍 DEBUG: Takım üye sayısı: X
✅ Üyeler yüklendi:
   - [İsim] ([User ID])
```

### Olası Durumlar:

#### Durum 1: "Takım üye sayısı: 0"
**Sorun**: RLS politikaları üyeleri göstermiyor

**Çözüm**:
1. Supabase Dashboard → **Database** → **Tables** → `team_members`
2. RLS'in aktif olduğunu kontrol edin
3. Policies sekmesinde şu politikalar olmalı:
   - `team_members_select_policy`
   - `team_members_insert_policy`

4. Manuel olarak bir üye ekleyin:
   ```sql
   -- SQL Editor'de çalıştırın
   INSERT INTO team_members (team_id, user_id, role, invited_by)
   VALUES (
     '[TAKIM_ID]',  -- Takımlarım sayfasından takım ID'sini alın
     auth.uid(),     -- Kendinizi ekler
     'owner',
     auth.uid()
   );
   ```

#### Durum 2: "Yükleme hatası: ..."
**Sorun**: Veritabanı hatası

**Çözüm**:
1. Supabase Dashboard → **Logs** → **Postgres Logs**
2. Son hataları kontrol edin
3. "permission denied" görüyorsanız → RLS politikalarını kontrol edin
4. "relation does not exist" görüyorsanız → `fix_all_issues.sql` tekrar çalıştırın

#### Durum 3: Dropdown boş ama log'da üyeler var
**Sorun**: Widget render sorunu

**Çözüm**:
```bash
# Hot reload yerine tam restart yapın
r  # Restart (değil)
R  # Hot Restart
```

## 📋 DETAYLI KONTROL LİSTESİ

### Veritabanı Kontrolü

Supabase Dashboard'da şu tabloların var olduğunu kontrol edin:

```sql
-- SQL Editor'de çalıştırın
SELECT 
  table_name, 
  (SELECT COUNT(*) FROM information_schema.table_constraints 
   WHERE constraint_type = 'PRIMARY KEY' 
   AND table_constraints.table_name = tables.table_name) as has_pk
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN (
  'teams', 
  'team_members', 
  'boards', 
  'cards', 
  'card_events', 
  'card_comments', 
  'notifications'
)
ORDER BY table_name;
```

**Beklenen Sonuç**: 7 satır (hepsi has_pk = 1 olmalı)

### RLS Kontrolü

```sql
-- SQL Editor'de çalıştırın
SELECT 
  schemaname, 
  tablename, 
  rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN (
  'teams', 
  'team_members', 
  'boards', 
  'cards', 
  'card_events', 
  'card_comments', 
  'notifications'
);
```

**Beklenen Sonuç**: Hepsinde `rowsecurity = true` olmalı

### Politika Kontrolü

```sql
-- SQL Editor'de çalıştırın
SELECT 
  tablename, 
  policyname, 
  cmd 
FROM pg_policies 
WHERE schemaname = 'public'
ORDER BY tablename, cmd;
```

**Beklenen Sonuç**: En az 20+ politika görmeli

## 🛠️ MANUEL TAMIR (SQL Script Çalışmazsa)

Eğer `fix_all_issues.sql` hata veriyorsa, adım adım yapın:

### Adım 1: Enum'ları Düzelt

```sql
-- COMMENTED ekle
ALTER TYPE card_event_type ADD VALUE IF NOT EXISTS 'COMMENTED';
```

### Adım 2: Tabloları Kontrol Et

```sql
-- Eksik tabloları kontrol et
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'teams') 
    THEN '✅ teams var' 
    ELSE '❌ teams yok' 
  END as teams_check,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'team_members') 
    THEN '✅ team_members var' 
    ELSE '❌ team_members yok' 
  END as team_members_check,
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'card_comments') 
    THEN '✅ card_comments var' 
    ELSE '❌ card_comments yok' 
  END as card_comments_check;
```

Eksik olan tabloları `migration_team_kanban.sql` veya `migration_comments_and_notifications.sql` ile oluşturun.

### Adım 3: RLS Politikalarını Sıfırla

```sql
-- Tüm politikaları sil
DROP POLICY IF EXISTS teams_select_policy ON teams;
DROP POLICY IF EXISTS teams_insert_policy ON teams;
DROP POLICY IF EXISTS teams_update_policy ON teams;
DROP POLICY IF EXISTS teams_delete_policy ON teams;

DROP POLICY IF EXISTS team_members_select_policy ON team_members;
DROP POLICY IF EXISTS team_members_insert_policy ON team_members;
DROP POLICY IF EXISTS team_members_update_policy ON team_members;
DROP POLICY IF EXISTS team_members_delete_policy ON team_members;

-- Sonra fix_all_issues.sql'deki politika kısmını çalıştırın
```

## 💡 ÖNERİLER

### Geliştirme Ortamı İçin

Test amaçlı RLS'i geçici olarak kapatabilirsiniz:

```sql
-- SADECE TEST İÇİN! Production'da asla yapma!
ALTER TABLE team_members DISABLE ROW LEVEL SECURITY;
```

Sorun çözülünce tekrar açın:

```sql
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
```

### Production İçin

- ✅ Tüm migration'ları versiyon kontrolüne ekleyin
- ✅ Migration'ları numaralandırın (001_, 002_, vb.)
- ✅ Her migration için rollback scripti hazırlayın
- ✅ Production'da test etmeden önce staging'de test edin

## 📞 DESTEK

Hala sorun varsa, şu bilgileri paylaşın:

1. **Console Output**:
   ```
   🔍 DEBUG: Takım üye sayısı: ?
   ```

2. **Supabase Logs**: 
   - Dashboard → Logs → Postgres Logs'dan son 10 satır

3. **Politika Kontrolü**:
   ```sql
   SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public';
   ```

4. **Tablo Kontrolü**:
   ```sql
   SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';
   ```

## ✅ BAŞARILI KURULUM

Script başarıyla çalıştıktan sonra:

```
✅ Kart görünümleri düzgün
✅ Kart eklerken atama dropdown'u çalışıyor
✅ Bildirimler geliyor
✅ Takım sayfası çalışıyor
✅ Yorumlar eklenebiliyor
✅ Durum değişiklikleri çalışıyor
```

---

**Son Güncelleme**: 2026-02-05
**Versiyon**: 2.0 (Kapsamlı Fix)
