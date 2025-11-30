-- Jet Fan sistemi için gerekli yeni sütunları tickets tablosuna ekler

ALTER TABLE tickets ADD COLUMN IF NOT EXISTS zone_count INTEGER; -- Kaç Zone var?
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS jetfan_count INTEGER; -- Toplam Jetfan Sayısı
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS bidirectional_jetfan_count INTEGER; -- Kaçı Çift Yönlü?
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS inverter_count INTEGER; -- Kaç İnverter (Sürücü) var?
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS inverter_brand TEXT; -- İnverter Markası

