-- ticket_notes tablosuna resim URL'ini saklamak için sütun ekle
ALTER TABLE public.ticket_notes 
ADD COLUMN IF NOT EXISTS image_url text;

