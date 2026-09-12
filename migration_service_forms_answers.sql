-- Servis oncesi onay formundaki her maddeye Evet/Hayir olarak gercek bir
-- cevap kaydedebilmek icin. `checked_items` sadece "isaretlenen" (yani
-- Evet secilen) maddelerin indeksini tutuyordu; "Hayir" secilen zorunlu bir
-- madde formu gonderilemez hale getiriyordu, cunku "isaretli degil" ile
-- "cevaplanmadi" ayirt edilemiyordu.
--
-- `answers`, {"0": true, "1": false, ...} seklinde HER maddenin gercek
-- cevabini tutar (index -> Evet/Hayir). `checked_items` geriye donuk
-- uyumluluk icin hala doldurulur (answers icinde true olanlarin indeksleri).
alter table public.ticket_service_forms
  add column if not exists answers jsonb default '{}'::jsonb;
