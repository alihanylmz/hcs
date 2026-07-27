-- Eski kurulumlarda varchar olarak kalmis olabilecek teklif notlarini
-- PostgreSQL'in sinirsiz text tipine normalize eder.
alter table public.quotes
alter column note type text using note::text;
