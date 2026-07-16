-- Removes legacy gold/silver market-rate rows.
-- Run after schema.sql if older seed/fill scripts inserted these rows.

delete from public.market_rates
where code in ('XAUTRY_GRAM', 'XAGTRY_GRAM');
