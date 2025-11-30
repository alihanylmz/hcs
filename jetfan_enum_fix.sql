-- Supabase'deki device_model_enum tipine 'Jet Fan' değerini ekler
-- Bu işlem bir transaction içinde yapılamaz, o yüzden doğrudan çalıştırılmalıdır.

ALTER TYPE device_model_enum ADD VALUE IF NOT EXISTS 'Jet Fan';



