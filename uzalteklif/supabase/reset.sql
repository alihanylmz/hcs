-- Uzal Teklif destructive reset
-- Drops application tables and helper function. Use only in development.

drop table if exists public.quotes cascade;
drop table if exists public.products cascade;
drop table if exists public.market_rates cascade;
drop function if exists public.set_updated_at() cascade;
