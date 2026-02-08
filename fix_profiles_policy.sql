-- ============================================
-- PROFILES TABLOSU İÇİN RLS POLİTİKASI DÜZELTMESİ
-- ============================================
-- Takım üyelerinin birbirlerini görebilmesi için
-- profiles tablosundan okuma yetkisi gerekiyor
-- ============================================

-- RLS aktif et (eğer değilse)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Mevcut policy'leri kaldır
DROP POLICY IF EXISTS profiles_select_policy ON profiles;
DROP POLICY IF EXISTS profiles_update_policy ON profiles;
DROP POLICY IF EXISTS profiles_insert_policy ON profiles;

-- SELECT: HERKES profiles'ı okuyabilir (takım üyelerini görmek için gerekli)
CREATE POLICY profiles_select_policy ON profiles
    FOR SELECT
    USING (true);

-- UPDATE: Kullanıcı sadece kendi profilini güncelleyebilir
CREATE POLICY profiles_update_policy ON profiles
    FOR UPDATE
    USING (id = auth.uid());

-- INSERT: Sadece kendi profilini oluşturabilir (signup sırasında)
CREATE POLICY profiles_insert_policy ON profiles
    FOR INSERT
    WITH CHECK (id = auth.uid());

-- ============================================
-- PROFILES RLS DÜZELTMESİ TAMAMLANDI ✅
-- ============================================
-- Artık tüm kullanıcılar profiles tablosunu okuyabilir
-- Bu sayede dropdown'da kullanıcılar görünecek
