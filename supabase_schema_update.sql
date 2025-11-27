-- 1. Eğer 'profiles' tablosunda 'role' sütunu yoksa ekle
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN 
        ALTER TABLE profiles ADD COLUMN role text DEFAULT 'technician'; 
    END IF; 
END $$;

-- 2. Sizin kullanıcınızı admin yap (E-postanızı buraya yazın)
-- ÖNEMLİ: Aşağıdaki e-posta adresini kendi giriş yaptığınız e-posta ile değiştirin!
UPDATE profiles 
SET role = 'admin' 
WHERE id IN (SELECT id FROM auth.users WHERE email = 'admin@admin.com'); 
-- Eğer kendi emailinizi bilmiyorsanız, tüm kullanıcıları admin yapmak için (tehlikeli olabilir):
-- UPDATE profiles SET role = 'admin';

