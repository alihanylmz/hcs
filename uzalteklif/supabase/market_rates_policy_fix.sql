-- Allows the desktop app to read public market rates with the anon key.
-- Run this in Supabase SQL Editor if market_rates has rows but the app shows fallback rates.

alter table public.market_rates enable row level security;

drop policy if exists "Allow authenticated users to read market rates" on public.market_rates;
drop policy if exists "Allow public users to read market rates" on public.market_rates;

create policy "Allow public users to read market rates"
on public.market_rates
for select
to anon, authenticated
using (true);
