-- ticket_notes tablosuna note_type kolonu ekleme
-- Bu kolon notun tipini belirtir: 'service_note' veya 'partner_note'

-- 1. Kolonu ekle (NULL olabilir, eski kayıtlar için)
ALTER TABLE public.ticket_notes 
ADD COLUMN IF NOT EXISTS note_type text;

-- 2. Eski kayıtlar için varsayılan değer ata (servis notu)
UPDATE public.ticket_notes 
SET note_type = 'service_note' 
WHERE note_type IS NULL;

-- 3. Varsayılan değer ekle (yeni kayıtlar için)
ALTER TABLE public.ticket_notes 
ALTER COLUMN note_type SET DEFAULT 'service_note';

-- 4. (Opsiyonel) NOT NULL constraint ekle (eğer istersen)
-- ALTER TABLE public.ticket_notes 
-- ALTER COLUMN note_type SET NOT NULL;

-- 5. (Opsiyonel) Check constraint ekle (sadece belirli değerler kabul et)
-- Önce varsa kaldır, sonra ekle
DO $$ 
BEGIN
    -- Constraint varsa kaldır
    IF EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'check_note_type' 
        AND conrelid = 'public.ticket_notes'::regclass
    ) THEN
        ALTER TABLE public.ticket_notes DROP CONSTRAINT check_note_type;
    END IF;
    
    -- Constraint ekle
    ALTER TABLE public.ticket_notes 
    ADD CONSTRAINT check_note_type 
    CHECK (note_type IS NULL OR note_type IN ('service_note', 'partner_note'));
EXCEPTION
    WHEN duplicate_object THEN
        -- Constraint zaten varsa hiçbir şey yapma
        NULL;
END $$;

-- 6. Index ekle (performans için, opsiyonel)
CREATE INDEX IF NOT EXISTS idx_ticket_notes_note_type 
ON public.ticket_notes(note_type);

