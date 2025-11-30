
-- Jet Fan detaylarını (duman ve taze hava fanları listesi) tutmak için JSONB sütunu ekler
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS jetfan_details JSONB;

