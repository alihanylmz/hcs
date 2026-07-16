-- Uzal Teklif current market-rate fill
-- Source for USD/EUR: TCMB today.xml ForexSelling, Bulletin 2026/82, 30.04.2026.
-- Run after supabase/schema.sql.

insert into public.market_rates (
  code,
  label,
  unit_label,
  value,
  is_fallback,
  sort_order,
  updated_at
) values
  ('USDTRY', 'Dolar', '1 USD', 45.0502, false, 10, '2026-04-30T12:00:00+03:00'),
  ('EURTRY', 'Euro', '1 EUR', 52.6670, false, 20, '2026-04-30T12:00:00+03:00')
on conflict (code) do update set
  label = excluded.label,
  unit_label = excluded.unit_label,
  value = excluded.value,
  is_fallback = excluded.is_fallback,
  sort_order = excluded.sort_order,
  updated_at = excluded.updated_at;
