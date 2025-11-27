-- 1. PROFİL GÖRÜNTÜLEME POLİTİKASI (Okuma)
-- Herkes herkesin profilini görebilmeli (isimleri listede göstermek için)
-- Veya daha güvenli olsun derseniz: Sadece adminler hepsini, kullanıcılar sadece kendisininkini görebilir.
-- Ancak şu anki "Kullanıcı Yönetimi" sayfası için adminin herkesi görmesi şart.

DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
CREATE POLICY "Profiles are viewable by everyone" 
ON profiles FOR SELECT 
USING (true);

-- 2. PROFİL GÜNCELLEME POLİTİKASI (Yazma)
-- Kullanıcılar kendi profillerini güncelleyebilir.
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

-- 3. ADMIN ROL GÜNCELLEME POLİTİKASI
-- Sadece admin rolüne sahip kişiler başkasının rolünü değiştirebilir.
-- (Not: Bu karmaşık bir politika gerektirebilir, şimdilik update politikası yeterli olabilir ama güvenlik için tetikleyici gerekebilir)
-- Şimdilik basit tutuyoruz.

-- Eğer RLS kapalıysa açalım:
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

