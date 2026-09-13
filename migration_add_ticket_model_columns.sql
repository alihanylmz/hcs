-- edit_ticket_page.dart, aspirator/vantilator surucu markasi (aspirator_brand /
-- vant_brand - zaten vardi) yaninda MODELini de kaydetmeye calisiyordu
-- ('aspirator_model' / 'vant_model'), ama bu iki sutun tabloda hic yoktu.
-- Sonuc: is emrini duzenleyip kaydetmeye calisan HERKES PostgREST'ten
-- "Could not find the 'aspirator_model' column of 'tickets' in the schema
-- cache" hatasi aliyordu - RLS/yetki sorunu degil, dogrudan eksik sutundu.
alter table public.tickets
  add column if not exists aspirator_model text,
  add column if not exists vant_model text;
