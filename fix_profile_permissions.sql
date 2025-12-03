-- PROFIL TABLOSU GÜVENLİK AYARLARI (RLS DÜZELTME)

-- 1. Önce eski/hatalı politikaları temizleyelim ki çakışma olmasın
DROP POLICY IF EXISTS "Public profiles are viewable by everyone." ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile." ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile." ON public.profiles;
DROP POLICY IF EXISTS "Herkes profilleri görebilir" ON public.profiles;
DROP POLICY IF EXISTS "Adminler ve kullanıcılar profilleri güncelleyebilir" ON public.profiles;
DROP POLICY IF EXISTS "Profil Güncelleme İzni" ON public.profiles;
DROP POLICY IF EXISTS "Profilleri Okuma İzni" ON public.profiles;

-- 2. RLS'i Aktif Et (Zaten aktifse sorun yok)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 3. OKUMA İZNİ: Giriş yapmış herkes profilleri görebilsin (Listeleme için şart)
CREATE POLICY "Profilleri Okuma İzni" ON public.profiles
FOR SELECT
USING (auth.role() = 'authenticated');

-- 4. GÜNCELLEME İZNİ: (Kritik Nokta Burası)
-- Kural: "Kullanıcı ya kendisidir YA DA Admindir."
CREATE POLICY "Profil Güncelleme İzni" ON public.profiles
FOR UPDATE
USING (
  -- Kişi kendisi mi?
  auth.uid() = id 
  OR 
  -- Kişi Admin mi? (Admin ise herkese erişebilir)
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  )
);

-- 5. EKLEME İZNİ: Yeni üye olduğunda profil oluşsun
CREATE POLICY "Profil Ekleme İzni" ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

