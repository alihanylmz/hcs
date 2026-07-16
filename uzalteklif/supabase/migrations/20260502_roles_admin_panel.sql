-- Role model hardening for admin / manager / sales / finance / operations / viewer.

alter table public.user_profiles drop constraint if exists user_profiles_role_check;
alter table public.user_profiles
add constraint user_profiles_role_check
check (
  role in (
    'admin',
    'manager',
    'sales',
    'finance',
    'operations',
    'viewer',
    'seller',
    'sales_engineer',
    'mechatronics_engineer',
    'electrical_electronics_engineer',
    'accountant'
  )
)
not valid;

create or replace function public.is_quote_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select u.role in ('admin', 'manager')
     from public.user_profiles u
     where u.user_id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_quote_manager() to authenticated;

create or replace function public.is_system_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select u.role = 'admin'
     from public.user_profiles u
     where u.user_id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_system_admin() to authenticated;

drop policy if exists "Managers update all profiles" on public.user_profiles;
create policy "Managers update all profiles"
on public.user_profiles
for update
to authenticated
using (public.is_system_admin())
with check (public.is_system_admin());

create or replace function public.user_profiles_preserve_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_system_admin() then
    new.role := old.role;
  end if;
  return new;
end;
$$;

drop policy if exists "Allow authenticated users to write products" on public.products;
create policy "Allow authenticated users to write products"
on public.products
for all
to authenticated
using (public.is_quote_manager() or exists (
  select 1 from public.user_profiles u
  where u.user_id = auth.uid()
    and u.role in ('operations', 'finance')
))
with check (public.is_quote_manager() or exists (
  select 1 from public.user_profiles u
  where u.user_id = auth.uid()
    and u.role in ('operations', 'finance')
));
