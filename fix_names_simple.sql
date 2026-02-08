-- ============================================
-- İSİM SORUNU İÇİN BASİT ÇÖZÜM
-- ============================================

-- 1. Profiles tablosunu oluştur (Zaten varsa hiçbir şey yapmaz)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  email text,
  full_name text
);

-- 2. Herkesin okumasına izin ver (Kritik adım)
alter table public.profiles enable row level security;

do $$ begin
  drop policy if exists "Public profiles" on public.profiles;
  create policy "Public profiles" on public.profiles for select using (true);
exception when others then null; end $$;

-- 3. Eksik isimleri auth tablosundan kopyala
insert into public.profiles (id, email, full_name)
select 
  id, 
  email,
  coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', email)
from auth.users
on conflict (id) do update
set email = excluded.email, full_name = excluded.full_name;

-- ============================================
-- ARTIK İSİMLER GÖRÜNECEK! ✅
-- ============================================
