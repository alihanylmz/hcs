-- Signup / profile altyapisi
-- Supabase SQL Editor'da bir kez calistir.

create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  role text not null default 'pending',
  partner_id bigint,
  signature_data text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists email text,
  add column if not exists full_name text,
  add column if not exists role text default 'pending',
  add column if not exists partner_id bigint,
  add column if not exists signature_data text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

update public.profiles
set role = 'pending'
where role is null;

alter table public.profiles enable row level security;

create or replace function public.can_manage_profiles(p_actor_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles actor
    where actor.id = p_actor_id
      and actor.role in ('admin', 'manager')
  );
$$;

grant execute on function public.can_manage_profiles(uuid) to authenticated;

drop policy if exists profiles_select_policy on public.profiles;
drop policy if exists profiles_insert_policy on public.profiles;
drop policy if exists profiles_update_policy on public.profiles;

create policy profiles_select_policy
on public.profiles
for select
using (
  auth.uid() = id
  or public.can_manage_profiles(auth.uid())
);

create policy profiles_insert_policy
on public.profiles
for insert
with check (auth.uid() = id);

create policy profiles_update_policy
on public.profiles
for update
using (
  auth.uid() = id
  or public.can_manage_profiles(auth.uid())
)
with check (
  auth.uid() = id
  or public.can_manage_profiles(auth.uid())
);

create or replace function public.set_profiles_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute procedure public.set_profiles_updated_at();

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email),
    'pending'
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    role = coalesce(public.profiles.role, 'pending'),
    updated_at = now();

  return new;
end;
$$ language plpgsql security definer set search_path = public, auth;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();

insert into public.profiles (id, email, full_name, role)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', u.email),
  'pending'
from auth.users u
on conflict (id) do update
set
  email = excluded.email,
  full_name = coalesce(public.profiles.full_name, excluded.full_name),
  role = coalesce(public.profiles.role, 'pending'),
  updated_at = now();
