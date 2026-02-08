-- ============================================
-- EKSİK İSİM VE PROFİLLERİ DÜZELTME
-- "İsimsiz Üye" sorununu çözer
-- ============================================

-- 1. Profiles tablosunu garantiye al (Yoksa oluştur)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email text,
  full_name text,
  avatar_url text,
  updated_at timestamptz DEFAULT now()
);

-- RLS (Güvenlik) Ayarları
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Herkes profilleri görebilsin (İsimlerin görünmesi için şart)
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
CREATE POLICY "Users can insert their own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- 2. Mevcut Kullanıcıları Profiles Tablosuna Aktar
-- auth.users tablosundaki e-posta ve isimleri kopyalar
INSERT INTO public.profiles (id, email, full_name)
SELECT 
  id, 
  email, 
  COALESCE(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', email) as full_name
FROM auth.users
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  full_name = COALESCE(public.profiles.full_name, EXCLUDED.full_name);

-- 3. Yeni Kayıtlarda Otomatik Profil Oluşturma (Trigger)
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    new.id, 
    new.email, 
    COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email)
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 4. İLİŞKİLERİ KUR (JOIN SORUNUNU ÇÖZER)
-- Supabase'in "profiles" tablosuna join atabilmesi için FK ekliyoruz

-- Team Members -> Profiles
ALTER TABLE public.team_members 
DROP CONSTRAINT IF EXISTS team_members_user_id_fkey_profiles;

ALTER TABLE public.team_members
ADD CONSTRAINT team_members_user_id_fkey_profiles
FOREIGN KEY (user_id) REFERENCES public.profiles(id);

-- Cards (Assignee) -> Profiles
ALTER TABLE public.cards
DROP CONSTRAINT IF EXISTS cards_assignee_id_fkey_profiles;

ALTER TABLE public.cards
ADD CONSTRAINT cards_assignee_id_fkey_profiles
FOREIGN KEY (assignee_id) REFERENCES public.profiles(id);

-- Cards (Creator) -> Profiles
ALTER TABLE public.cards
DROP CONSTRAINT IF EXISTS cards_created_by_fkey_profiles;

ALTER TABLE public.cards
ADD CONSTRAINT cards_created_by_fkey_profiles
FOREIGN KEY (created_by) REFERENCES public.profiles(id);

-- Card Events -> Profiles
ALTER TABLE public.card_events
DROP CONSTRAINT IF EXISTS card_events_user_id_fkey_profiles;

ALTER TABLE public.card_events
ADD CONSTRAINT card_events_user_id_fkey_profiles
FOREIGN KEY (user_id) REFERENCES public.profiles(id);

-- ============================================
-- İŞLEM TAMAMLANDI ✅
-- ============================================
