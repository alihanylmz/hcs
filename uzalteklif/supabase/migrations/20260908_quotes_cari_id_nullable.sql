-- Phase 3.4: Allow null cari_id to support manual customer entry without creating cari records

alter table public.quotes alter column cari_id drop not null;
alter table public.quotes alter column cari_id drop default;
alter table public.quotes alter column cari_id set default null;

-- Migrate existing empty cari_id values to null
update public.quotes set cari_id = null where cari_id = '';
