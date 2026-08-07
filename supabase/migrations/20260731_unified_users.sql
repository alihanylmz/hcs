-- Ortak kullanıcı omurgası: İş Takip `profiles` ana kimlik kaynağıdır.
-- Teklif uygulamasına özel profil alanları ve uygulama erişimi ayrı tutulur.
-- Bu migration yalnızca hedef/ortak İş Takip Supabase projesine uygulanmalıdır.

begin;

create table if not exists public.user_app_access (
  user_id uuid not null references public.profiles (id) on delete cascade,
  app_code text not null,
  app_role text not null default 'user',
  is_active boolean not null default true,
  granted_by uuid references public.profiles (id) on delete set null,
  granted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, app_code),
  constraint user_app_access_app_code_check
    check (app_code in ('is_takip', 'teklif')),
  constraint user_app_access_quote_role_check
    check (
      app_code <> 'teklif'
      or app_role in (
        'admin',
        'manager',
        'sales',
        'finance',
        'operations',
        'viewer'
      )
    )
);

create index if not exists user_app_access_app_active_idx
on public.user_app_access (app_code, is_active);

create table if not exists public.user_quote_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  prepared_by_title text not null default '',
  prepared_by_phone text not null default '',
  prepared_by_email text not null default '',
  company_name text not null default '',
  company_tagline text not null default '',
  company_phone text not null default '',
  company_email text not null default '',
  company_website text not null default '',
  company_address text not null default '',
  company_tax_office text not null default '',
  company_tax_number text not null default '',
  company_mersis text not null default '',
  bank_name text not null default '',
  bank_branch text not null default '',
  bank_account_name text not null default '',
  bank_iban text not null default '',
  bank_swift text not null default '',
  default_validity_text text not null default '',
  default_payment_terms text not null default '',
  default_delivery_terms text not null default '',
  default_vat_rate numeric(5,2) not null default 20,
  updated_at timestamptz not null default now(),
  constraint user_quote_settings_vat_check
    check (default_vat_rate >= 0 and default_vat_rate <= 100)
);

-- Yalnızca service_role tarafından kullanılan, eski ve yeni UUID ilişkisi.
create table if not exists public.auth_user_migration_map (
  source_system text not null default 'teklif',
  source_user_id uuid not null,
  target_user_id uuid references public.profiles (id) on delete set null,
  email text not null,
  migration_status text not null default 'pending',
  note text not null default '',
  migrated_at timestamptz,
  primary key (source_system, source_user_id),
  constraint auth_user_migration_status_check
    check (
      migration_status in (
        'pending',
        'matched',
        'invited',
        'migrated',
        'skipped',
        'error'
      )
    )
);

create unique index if not exists auth_user_migration_email_idx
on public.auth_user_migration_map (source_system, lower(email));

create or replace function public.is_unified_user_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role in ('admin', 'manager')
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

grant execute on function public.is_unified_user_manager() to authenticated;

create or replace function public.set_unified_user_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists user_app_access_set_updated_at
on public.user_app_access;
create trigger user_app_access_set_updated_at
before update on public.user_app_access
for each row execute function public.set_unified_user_updated_at();

drop trigger if exists user_quote_settings_set_updated_at
on public.user_quote_settings;
create trigger user_quote_settings_set_updated_at
before update on public.user_quote_settings
for each row execute function public.set_unified_user_updated_at();

-- Mevcut İş Takip kullanıcıları İş Takip erişimini aynen korur.
insert into public.user_app_access (
  user_id,
  app_code,
  app_role,
  is_active
)
select
  p.id,
  'is_takip',
  coalesce(nullif(p.role::text, ''), 'pending'),
  coalesce(p.role::text, 'pending') <> 'pending'
from public.profiles p
on conflict (user_id, app_code) do nothing;

-- İlk kurulumda yalnızca yönetici hesapları Teklif'e otomatik erişir.
-- Diğer Teklif kullanıcıları taşıma aracı tarafından e-posta ile eşleştirilir.
insert into public.user_app_access (
  user_id,
  app_code,
  app_role,
  is_active
)
select
  p.id,
  'teklif',
  case when p.role::text = 'admin' then 'admin' else 'manager' end,
  true
from public.profiles p
where p.role::text in ('admin', 'manager')
on conflict (user_id, app_code) do nothing;

create or replace function public.seed_new_profile_app_access()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_app_access (
    user_id,
    app_code,
    app_role,
    is_active
  )
  values (
    new.id,
    'is_takip',
    coalesce(nullif(new.role::text, ''), 'pending'),
    coalesce(new.role::text, 'pending') <> 'pending'
  )
  on conflict (user_id, app_code) do nothing;
  return new;
end;
$$;

drop trigger if exists profiles_seed_app_access on public.profiles;
create trigger profiles_seed_app_access
after insert on public.profiles
for each row execute function public.seed_new_profile_app_access();

alter table public.user_app_access enable row level security;
alter table public.user_quote_settings enable row level security;
alter table public.auth_user_migration_map enable row level security;

-- RLS politikalarının çalışabilmesi için gereken tablo izinleri açıkça verilir.
-- `auth_user_migration_map` hiçbir istemci rolüne açılmaz.
grant select, insert, update, delete
on public.user_app_access
to authenticated;

grant select, insert, update
on public.user_quote_settings
to authenticated;

revoke all
on public.user_app_access, public.user_quote_settings
from anon;

drop policy if exists user_app_access_select_scope
on public.user_app_access;
create policy user_app_access_select_scope
on public.user_app_access
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_unified_user_manager()
);

drop policy if exists user_app_access_manage_scope
on public.user_app_access;
create policy user_app_access_manage_scope
on public.user_app_access
for all
to authenticated
using (public.is_unified_user_manager())
with check (public.is_unified_user_manager());

drop policy if exists user_quote_settings_select_scope
on public.user_quote_settings;
create policy user_quote_settings_select_scope
on public.user_quote_settings
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_unified_user_manager()
);

drop policy if exists user_quote_settings_insert_own
on public.user_quote_settings;
create policy user_quote_settings_insert_own
on public.user_quote_settings
for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists user_quote_settings_update_scope
on public.user_quote_settings;
create policy user_quote_settings_update_scope
on public.user_quote_settings
for update
to authenticated
using (
  user_id = auth.uid()
  or public.is_unified_user_manager()
)
with check (
  user_id = auth.uid()
  or public.is_unified_user_manager()
);

-- Eski UserQuoteProfile modelinin okuyabileceği geriye uyumlu görünüm.
create or replace view public.quote_user_profiles
with (security_invoker = true)
as
select
  p.id as user_id,
  coalesce(p.full_name, '') as prepared_by_name,
  coalesce(q.prepared_by_title, '') as prepared_by_title,
  coalesce(q.prepared_by_phone, '') as prepared_by_phone,
  coalesce(nullif(q.prepared_by_email, ''), p.email, '') as prepared_by_email,
  coalesce(q.company_name, '') as company_name,
  coalesce(q.company_tagline, '') as company_tagline,
  coalesce(q.company_phone, '') as company_phone,
  coalesce(q.company_email, '') as company_email,
  coalesce(q.company_website, '') as company_website,
  coalesce(q.company_address, '') as company_address,
  coalesce(q.company_tax_office, '') as company_tax_office,
  coalesce(q.company_tax_number, '') as company_tax_number,
  coalesce(q.company_mersis, '') as company_mersis,
  coalesce(q.bank_name, '') as bank_name,
  coalesce(q.bank_branch, '') as bank_branch,
  coalesce(q.bank_account_name, '') as bank_account_name,
  coalesce(q.bank_iban, '') as bank_iban,
  coalesce(q.bank_swift, '') as bank_swift,
  coalesce(q.default_validity_text, '') as default_validity_text,
  coalesce(q.default_payment_terms, '') as default_payment_terms,
  coalesce(q.default_delivery_terms, '') as default_delivery_terms,
  coalesce(q.default_vat_rate, 20) as default_vat_rate,
  a.app_role as role,
  q.updated_at
from public.profiles p
join public.user_app_access a
  on a.user_id = p.id
 and a.app_code = 'teklif'
 and a.is_active
left join public.user_quote_settings q on q.user_id = p.id;

grant select on public.quote_user_profiles to authenticated;

-- Bu tablo istemci uygulamalarına açılmaz; yalnızca service_role erişir.
revoke all on public.auth_user_migration_map from anon, authenticated;

comment on table public.user_app_access is
  'Bir kullanıcının İş Takip ve Teklif uygulamalarına erişim yetkileri.';
comment on table public.user_quote_settings is
  'Teklif uygulamasına özel kullanıcı ve firma çıktı ayarları.';
comment on table public.auth_user_migration_map is
  'Kaynak Teklif Auth kullanıcısı ile ortak Auth kullanıcısı arasındaki taşıma kaydı.';

commit;
