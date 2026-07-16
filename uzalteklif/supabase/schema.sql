-- Uzal Teklif Supabase schema
-- Safe to run more than once in the Supabase SQL Editor.
-- Urun resimleri icin Storage (product-images bucket + RLS) dosyanin sonunda.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- HELPERS
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- PRODUCTS
-- ---------------------------------------------------------------------------

create table if not exists public.products (
  id text primary key,
  code text not null unique,
  name text not null,
  category text not null,
  brand text not null,
  model text not null,
  unit text not null default 'adet',
  currency_code text not null default 'TL',
  sale_price numeric(14,2) not null default 0,
  stock_quantity numeric(14,2) not null default 0,
  minimum_stock numeric(14,2) not null default 0,
  vat_rate numeric(5,2) not null default 20,
  lead_time text not null default '',
  description text not null default '',
  technical_summary text not null default '',
  is_active boolean not null default true,
  image_path text not null default '',
  specifications jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now())
);

-- Older drafts of the schema used uuid ids. The Flutter app uses string ids
-- such as product-001 and quote-260501..., so normalize existing tables.
alter table public.products
alter column id drop default;

alter table public.products
alter column id type text using id::text;

alter table public.products
add column if not exists image_path text not null default '';

alter table public.products
add column if not exists specifications jsonb not null default '{}'::jsonb;

alter table public.products drop constraint if exists products_currency_code_check;
alter table public.products
add constraint products_currency_code_check
check (currency_code in ('TL', 'USDTRY', 'EURTRY'))
not valid;

alter table public.products drop constraint if exists products_sale_price_check;
alter table public.products
add constraint products_sale_price_check
check (sale_price >= 0)
not valid;

alter table public.products drop constraint if exists products_stock_quantity_check;
alter table public.products
add constraint products_stock_quantity_check
check (stock_quantity >= 0)
not valid;

alter table public.products drop constraint if exists products_minimum_stock_check;
alter table public.products
add constraint products_minimum_stock_check
check (minimum_stock >= 0)
not valid;

alter table public.products drop constraint if exists products_vat_rate_check;
alter table public.products
add constraint products_vat_rate_check
check (vat_rate >= 0 and vat_rate <= 100)
not valid;

create index if not exists products_category_idx on public.products (category);
create index if not exists products_brand_idx on public.products (brand);
create index if not exists products_is_active_idx on public.products (is_active);
create index if not exists products_updated_at_idx on public.products (updated_at desc);

drop trigger if exists products_set_updated_at on public.products;
create trigger products_set_updated_at
before update on public.products
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- QUOTES
-- ---------------------------------------------------------------------------

create table if not exists public.quotes (
  id text primary key,
  code text not null unique,
  customer_name text not null,
  customer_company text not null,
  title text not null,
  note text not null default '',
  display_unit text not null default 'TL',
  subtotal_tl numeric(14,2) not null default 0,
  items jsonb not null default '[]'::jsonb,
  hidden_costs jsonb not null default '[]'::jsonb,
  market_snapshot jsonb not null default '[]'::jsonb,
  document_profile jsonb not null default '{}'::jsonb,
  public_token text not null default '',
  payment_method text not null default 'cash',
  payment_term_days integer not null default 0,
  hide_prices boolean not null default false,
  sections jsonb not null default '[]'::jsonb,
  status text not null default 'draft',
  submitted_at timestamptz,
  approved_at timestamptz,
  approved_by uuid references auth.users (id) on delete set null,
  approved_by_name text not null default '',
  approval_note text not null default '',
  accepted_total_tl numeric(14,2),
  accepted_amount numeric(14,2),
  accepted_currency_code text not null default 'TL',
  accepted_fx_rate numeric(14,6),
  accepted_note text not null default '',
  accepted_at timestamptz,
  accepted_by uuid references auth.users (id) on delete set null,
  accepted_by_name text not null default '',
  revision_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.quotes
alter column id drop default;

do $$
begin
  if to_regclass('public.quote_line_items') is not null then
    drop policy if exists "quote_line_items_select_scope" on public.quote_line_items;
  end if;
end;
$$;

alter table public.quotes
alter column id type text using id::text;

alter table public.quotes
add column if not exists hidden_costs jsonb not null default '[]'::jsonb;

alter table public.quotes
add column if not exists public_token text not null default '';

alter table public.quotes
add column if not exists payment_method text not null default 'cash';

alter table public.quotes
add column if not exists payment_term_days integer not null default 0;

alter table public.quotes
add column if not exists hide_prices boolean not null default false;

alter table public.quotes
add column if not exists sections jsonb not null default '[]'::jsonb;

alter table public.quotes
add column if not exists status text not null default 'draft';

alter table public.quotes
add column if not exists submitted_at timestamptz;

alter table public.quotes
add column if not exists approved_at timestamptz;

alter table public.quotes
add column if not exists approved_by uuid references auth.users (id) on delete set null;

alter table public.quotes
add column if not exists approved_by_name text not null default '';

alter table public.quotes
add column if not exists approval_note text not null default '';

alter table public.quotes
add column if not exists accepted_total_tl numeric(14,2);

alter table public.quotes
add column if not exists accepted_amount numeric(14,2);

alter table public.quotes
add column if not exists accepted_currency_code text not null default 'TL';

alter table public.quotes
add column if not exists accepted_fx_rate numeric(14,6);

alter table public.quotes
add column if not exists accepted_note text not null default '';

alter table public.quotes
add column if not exists accepted_at timestamptz;

alter table public.quotes
add column if not exists accepted_by uuid references auth.users (id) on delete set null;

alter table public.quotes
add column if not exists accepted_by_name text not null default '';

alter table public.quotes
add column if not exists revision_count integer not null default 0;

alter table public.quotes drop constraint if exists quotes_display_unit_check;
alter table public.quotes
add constraint quotes_display_unit_check
check (display_unit in ('TL', 'USDTRY', 'EURTRY', 'XAUTRY_GRAM', 'XAGTRY_GRAM'))
not valid;

alter table public.quotes drop constraint if exists quotes_subtotal_tl_check;
alter table public.quotes
add constraint quotes_subtotal_tl_check
check (subtotal_tl >= 0)
not valid;

alter table public.quotes drop constraint if exists quotes_payment_method_check;
alter table public.quotes
add constraint quotes_payment_method_check
check (payment_method in ('cash', 'credit_card', 'installment'))
not valid;

alter table public.quotes drop constraint if exists quotes_payment_term_days_check;
alter table public.quotes
add constraint quotes_payment_term_days_check
check (payment_term_days >= 0 and payment_term_days <= 365)
not valid;

alter table public.quotes drop constraint if exists quotes_status_check;
alter table public.quotes
add constraint quotes_status_check
check (status in ('draft', 'sent', 'pending', 'approved', 'accepted', 'rejected', 'cancelled'))
not valid;

alter table public.quotes drop constraint if exists quotes_revision_count_check;
alter table public.quotes
add constraint quotes_revision_count_check
check (revision_count >= 0)
not valid;

alter table public.quotes drop constraint if exists quotes_accepted_total_tl_check;
alter table public.quotes
add constraint quotes_accepted_total_tl_check
check (accepted_total_tl is null or accepted_total_tl >= 0)
not valid;

alter table public.quotes drop constraint if exists quotes_accepted_amount_check;
alter table public.quotes
add constraint quotes_accepted_amount_check
check (accepted_amount is null or accepted_amount >= 0)
not valid;

alter table public.quotes drop constraint if exists quotes_accepted_currency_code_check;
alter table public.quotes
add constraint quotes_accepted_currency_code_check
check (accepted_currency_code in ('TL', 'USDTRY', 'EURTRY'))
not valid;

alter table public.quotes drop constraint if exists quotes_accepted_fx_rate_check;
alter table public.quotes
add constraint quotes_accepted_fx_rate_check
check (accepted_fx_rate is null or accepted_fx_rate > 0)
not valid;

create index if not exists quotes_created_at_idx on public.quotes (created_at desc);
create index if not exists quotes_status_idx on public.quotes (status);
create index if not exists quotes_public_token_idx
on public.quotes (public_token)
where public_token <> '';

alter table public.quotes
add column if not exists cari_id text not null default '';

alter table public.quotes
add column if not exists created_by uuid references auth.users (id) on delete set null;

alter table public.quotes
add column if not exists created_by_name text not null default '';

alter table public.quotes
add column if not exists archived_at timestamptz;

create index if not exists quotes_archived_at_idx
on public.quotes (archived_at desc nulls last);

create index if not exists quotes_created_by_idx on public.quotes (created_by);

create or replace function public.quotes_set_creator()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is null and auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists quotes_set_creator on public.quotes;
create trigger quotes_set_creator
before insert on public.quotes
for each row
execute function public.quotes_set_creator();

create or replace function public.user_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif((select up.prepared_by_name from public.user_profiles up where up.user_id = p_user_id), ''),
    nullif((select au.raw_user_meta_data ->> 'full_name' from auth.users au where au.id = p_user_id), ''),
    nullif((select au.raw_user_meta_data ->> 'name' from auth.users au where au.id = p_user_id), ''),
    (select au.email from auth.users au where au.id = p_user_id),
    ''
  );
$$;

grant execute on function public.user_display_name(uuid) to authenticated;

create or replace function public.quotes_fill_approval_and_acceptance_metadata()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor_id uuid;
  actor_name text;
begin
  actor_id := auth.uid();
  actor_name := public.user_display_name(actor_id);

  -- Status approved olunca onaylayan bilgisi otomatik dolar.
  if new.status = 'approved' and coalesce(old.status, '') <> 'approved' then
    if new.approved_at is null then
      new.approved_at := timezone('utc', now());
    end if;
    if new.approved_by is null then
      new.approved_by := actor_id;
    end if;
    if coalesce(new.approved_by_name, '') = '' then
      new.approved_by_name := actor_name;
    end if;
  end if;

  -- Ilk kez teklif kabul tutari girildiginde kaydi yapan kisi bilgisi dolar.
  if new.accepted_total_tl is not null and old.accepted_total_tl is null then
    if new.accepted_at is null then
      new.accepted_at := timezone('utc', now());
    end if;
    if new.accepted_by is null then
      new.accepted_by := actor_id;
    end if;
    if coalesce(new.accepted_by_name, '') = '' then
      new.accepted_by_name := actor_name;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists quotes_fill_approval_and_acceptance_metadata on public.quotes;
create trigger quotes_fill_approval_and_acceptance_metadata
before update on public.quotes
for each row
execute function public.quotes_fill_approval_and_acceptance_metadata();

-- ---------------------------------------------------------------------------
-- USER PROFILES (teklif PDF: firma + hazirlayan, kullanici basina)
-- ---------------------------------------------------------------------------

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  prepared_by_name text not null default '',
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
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.user_profiles
add column if not exists role text not null default 'seller';

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

-- RLS'te kullanilir; user_profiles.role eklendikten sonra tanimlanmali.
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

drop trigger if exists user_profiles_set_updated_at on public.user_profiles;
create trigger user_profiles_set_updated_at
before update on public.user_profiles
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- CUSTOMER ACCOUNTS (cari kartlari, hizli teklif musterisi)
-- ---------------------------------------------------------------------------

create table if not exists public.customer_accounts (
  id text primary key,
  company_name text not null default '',
  contact_name text not null default '',
  contact_title text not null default '',
  phone text not null default '',
  email text not null default '',
  tax_office text not null default '',
  tax_number text not null default '',
  address text not null default '',
  notes text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.customer_accounts
add column if not exists created_by uuid references auth.users (id) on delete set null;

create index if not exists customer_accounts_created_by_idx
on public.customer_accounts (created_by);

create index if not exists customer_accounts_company_lower_idx
on public.customer_accounts (lower(company_name));

drop trigger if exists customer_accounts_set_updated_at on public.customer_accounts;
create trigger customer_accounts_set_updated_at
before update on public.customer_accounts
for each row
execute function public.set_updated_at();

create or replace function public.customer_accounts_set_creator()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.created_by is null and auth.uid() is not null then
    new.created_by := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists customer_accounts_set_creator on public.customer_accounts;
create trigger customer_accounts_set_creator
before insert on public.customer_accounts
for each row
execute function public.customer_accounts_set_creator();

-- ---------------------------------------------------------------------------
-- PRICE ADJUSTMENT RULES (marka/kategori bazli toplu fiyat politikasi)
-- ---------------------------------------------------------------------------

create table if not exists public.price_adjustment_rules (
  id text primary key,
  name text not null default '',
  scope text not null default 'brand',
  brand text not null default '',
  category text not null default '',
  percentage numeric(8,2) not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.price_adjustment_rules drop constraint if exists price_adjustment_rules_scope_check;
alter table public.price_adjustment_rules
add constraint price_adjustment_rules_scope_check
check (scope in ('brand', 'category', 'brand_category'))
not valid;

alter table public.price_adjustment_rules drop constraint if exists price_adjustment_rules_percentage_check;
alter table public.price_adjustment_rules
add constraint price_adjustment_rules_percentage_check
check (percentage >= -100 and percentage <= 1000)
not valid;

create index if not exists price_adjustment_rules_scope_idx
on public.price_adjustment_rules (scope, brand, category);

drop trigger if exists price_adjustment_rules_set_updated_at on public.price_adjustment_rules;
create trigger price_adjustment_rules_set_updated_at
before update on public.price_adjustment_rules
for each row
execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- AUDIT / REVISION LOGS
-- ---------------------------------------------------------------------------

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users (id) on delete set null,
  table_name text not null,
  record_id text not null default '',
  action text not null,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists audit_logs_table_record_idx
on public.audit_logs (table_name, record_id, created_at desc);

create table if not exists public.quote_revisions (
  id uuid primary key default gen_random_uuid(),
  quote_id text not null,
  code text not null default '',
  revision_no integer not null default 0,
  snapshot jsonb not null,
  changed_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists quote_revisions_quote_idx
on public.quote_revisions (quote_id, created_at desc);

create table if not exists public.quote_line_items (
  id text primary key,
  quote_id text not null references public.quotes (id) on delete cascade,
  code text not null default '',
  description text not null default '',
  quantity numeric(14,4) not null default 0,
  unit text not null default '',
  unit_price_tl numeric(14,2) not null default 0,
  discount_rate numeric(6,2) not null default 0,
  section_id text not null default '',
  line_total_tl numeric(14,2) not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists quote_line_items_quote_idx
on public.quote_line_items (quote_id);

create index if not exists quote_line_items_code_idx
on public.quote_line_items (code);

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  record_key text;
begin
  record_key := coalesce((case when tg_op = 'DELETE' then old.id else new.id end)::text, '');
  insert into public.audit_logs (
    actor_id,
    table_name,
    record_id,
    action,
    old_data,
    new_data
  )
  values (
    auth.uid(),
    tg_table_name,
    record_key,
    tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create or replace function public.capture_quote_revision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.quote_revisions (
    quote_id,
    code,
    revision_no,
    snapshot,
    changed_by
  )
  values (
    old.id,
    old.code,
    coalesce(old.revision_count, 0),
    to_jsonb(old),
    auth.uid()
  );
  return new;
end;
$$;

create or replace function public.sync_quote_line_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  item_id text;
  item_index integer;
  item_description text;
  item_quantity numeric;
  item_unit_price numeric;
  item_discount numeric;
begin
  delete from public.quote_line_items where quote_id = new.id;

  for item, item_index in
    select value, ordinality::integer
    from jsonb_array_elements(coalesce(new.items, '[]'::jsonb)) with ordinality
  loop
    item_id := coalesce(item->>'id', gen_random_uuid()::text);
    item_description := coalesce(item->>'description', '');
    item_quantity := coalesce((item->>'quantity')::numeric, 0);
    item_unit_price := coalesce((item->>'unit_price_tl')::numeric, 0);
    item_discount := coalesce((item->>'discount_rate')::numeric, 0);

    insert into public.quote_line_items (
      id,
      quote_id,
      code,
      description,
      quantity,
      unit,
      unit_price_tl,
      discount_rate,
      section_id,
      line_total_tl
    )
    values (
      new.id || ':' || item_id || ':' || item_index,
      new.id,
      split_part(item_description, ' - ', 1),
      item_description,
      item_quantity,
      coalesce(item->>'unit', ''),
      item_unit_price,
      item_discount,
      coalesce(item->>'section_id', ''),
      item_quantity * item_unit_price * (1 - (item_discount / 100))
    )
    on conflict (id) do update set
      quote_id = excluded.quote_id,
      code = excluded.code,
      description = excluded.description,
      quantity = excluded.quantity,
      unit = excluded.unit,
      unit_price_tl = excluded.unit_price_tl,
      discount_rate = excluded.discount_rate,
      section_id = excluded.section_id,
      line_total_tl = excluded.line_total_tl;
  end loop;

  return new;
end;
$$;

drop trigger if exists quotes_audit_log on public.quotes;
create trigger quotes_audit_log
after insert or update or delete on public.quotes
for each row
execute function public.write_audit_log();

drop trigger if exists customer_accounts_audit_log on public.customer_accounts;
create trigger customer_accounts_audit_log
after insert or update or delete on public.customer_accounts
for each row
execute function public.write_audit_log();

drop trigger if exists products_audit_log on public.products;
create trigger products_audit_log
after insert or update or delete on public.products
for each row
execute function public.write_audit_log();

drop trigger if exists price_adjustment_rules_audit_log on public.price_adjustment_rules;
create trigger price_adjustment_rules_audit_log
after insert or update or delete on public.price_adjustment_rules
for each row
execute function public.write_audit_log();

drop trigger if exists quotes_capture_revision on public.quotes;
create trigger quotes_capture_revision
before update on public.quotes
for each row
execute function public.capture_quote_revision();

drop trigger if exists quotes_sync_line_items on public.quotes;
create trigger quotes_sync_line_items
after insert or update on public.quotes
for each row
execute function public.sync_quote_line_items();

-- ---------------------------------------------------------------------------
-- MARKET RATES
-- ---------------------------------------------------------------------------

create table if not exists public.market_rates (
  code text primary key,
  label text not null,
  unit_label text not null,
  value numeric(14,4) not null,
  is_fallback boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.market_rates
add column if not exists is_fallback boolean not null default false;

alter table public.market_rates
add column if not exists sort_order integer not null default 0;

alter table public.market_rates drop constraint if exists market_rates_code_check;
alter table public.market_rates
add constraint market_rates_code_check
check (code in ('USDTRY', 'EURTRY'))
not valid;

alter table public.market_rates drop constraint if exists market_rates_value_check;
alter table public.market_rates
add constraint market_rates_value_check
check (value > 0)
not valid;

create index if not exists market_rates_sort_order_idx
on public.market_rates (sort_order, code);

-- ---------------------------------------------------------------------------
-- RLS POLICIES
-- ---------------------------------------------------------------------------

alter table public.products enable row level security;
alter table public.quotes enable row level security;
alter table public.market_rates enable row level security;
alter table public.user_profiles enable row level security;
alter table public.customer_accounts enable row level security;
alter table public.price_adjustment_rules enable row level security;
alter table public.audit_logs enable row level security;
alter table public.quote_revisions enable row level security;
alter table public.quote_line_items enable row level security;

drop policy if exists "Allow authenticated users to read products" on public.products;
drop policy if exists "Allow authenticated users to write products" on public.products;
drop policy if exists "Allow authenticated users to read quotes" on public.quotes;
drop policy if exists "Allow authenticated users to write quotes" on public.quotes;
drop policy if exists "quotes_select_scope" on public.quotes;
drop policy if exists "quotes_insert_authenticated" on public.quotes;
drop policy if exists "quotes_update_scope" on public.quotes;
drop policy if exists "quotes_delete_scope" on public.quotes;
drop policy if exists "Allow authenticated users to read market rates" on public.market_rates;
drop policy if exists "Allow public users to read market rates" on public.market_rates;
drop policy if exists "Users manage own profile" on public.user_profiles;
drop policy if exists "Managers read all profiles" on public.user_profiles;
drop policy if exists "Managers update all profiles" on public.user_profiles;
drop policy if exists "Authenticated manage customer accounts" on public.customer_accounts;
drop policy if exists "customer_accounts_select_company" on public.customer_accounts;
drop policy if exists "customer_accounts_insert_authenticated" on public.customer_accounts;
drop policy if exists "customer_accounts_update_company" on public.customer_accounts;
drop policy if exists "customer_accounts_delete_scope" on public.customer_accounts;
drop policy if exists "Managers manage price adjustment rules" on public.price_adjustment_rules;
drop policy if exists "Authenticated read price adjustment rules" on public.price_adjustment_rules;
drop policy if exists "Managers read audit logs" on public.audit_logs;
drop policy if exists "Managers read quote revisions" on public.quote_revisions;
drop policy if exists "quote_line_items_select_scope" on public.quote_line_items;

create policy "Users manage own profile"
on public.user_profiles
for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Managers read all profiles"
on public.user_profiles
for select
to authenticated
using (public.is_quote_manager());

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

drop trigger if exists user_profiles_preserve_role on public.user_profiles;
create trigger user_profiles_preserve_role
before update on public.user_profiles
for each row
execute function public.user_profiles_preserve_role();

create policy "customer_accounts_select_company"
on public.customer_accounts
for select
to authenticated
using (true);

create policy "customer_accounts_insert_authenticated"
on public.customer_accounts
for insert
to authenticated
with check (
  created_by is null
  or created_by = auth.uid()
);

create policy "customer_accounts_update_company"
on public.customer_accounts
for update
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
)
with check (
  public.is_quote_manager()
  or created_by is null
  or created_by = auth.uid()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
);

create policy "customer_accounts_delete_scope"
on public.customer_accounts
for delete
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);

create policy "Authenticated read price adjustment rules"
on public.price_adjustment_rules
for select
to authenticated
using (true);

create policy "Managers manage price adjustment rules"
on public.price_adjustment_rules
for all
to authenticated
using (public.is_quote_manager())
with check (public.is_quote_manager());

create policy "Managers read audit logs"
on public.audit_logs
for select
to authenticated
using (public.is_quote_manager());

create policy "Managers read quote revisions"
on public.quote_revisions
for select
to authenticated
using (public.is_quote_manager());

create policy "quote_line_items_select_scope"
on public.quote_line_items
for select
to authenticated
using (
  public.is_quote_manager()
  or exists (
    select 1 from public.quotes q
    where q.id = quote_line_items.quote_id
      and q.created_by = auth.uid()
  )
);

create policy "Allow authenticated users to read products"
on public.products
for select
to authenticated
using (true);

create policy "Allow authenticated users to write products"
on public.products
for all
to authenticated
using (public.is_quote_manager() or exists (
  select 1 from public.user_profiles u
  where u.user_id = auth.uid()
    and u.role in (
      'sales',
      'seller',
      'sales_engineer',
      'mechatronics_engineer',
      'electrical_electronics_engineer',
      'operations',
      'finance'
    )
))
with check (public.is_quote_manager() or exists (
  select 1 from public.user_profiles u
  where u.user_id = auth.uid()
    and u.role in (
      'sales',
      'seller',
      'sales_engineer',
      'mechatronics_engineer',
      'electrical_electronics_engineer',
      'operations',
      'finance'
    )
));

create policy "quotes_select_scope"
on public.quotes
for select
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);

create policy "quotes_insert_authenticated"
on public.quotes
for insert
to authenticated
with check (
  created_by is null or created_by = auth.uid()
);

create policy "quotes_update_scope"
on public.quotes
for update
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
)
with check (
  public.is_quote_manager()
  or created_by = auth.uid()
);

create policy "quotes_delete_scope"
on public.quotes
for delete
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);

create policy "Allow public users to read market rates"
on public.market_rates
for select
to anon, authenticated
using (true);

-- ---------------------------------------------------------------------------
-- STORAGE: PRODUCT IMAGES (urun karti / detay JPEG; uygulama sikistirarak yukler)
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  1572864,
  array['image/jpeg']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "product_images_public_read" on storage.objects;
drop policy if exists "product_images_auth_insert" on storage.objects;
drop policy if exists "product_images_auth_update" on storage.objects;
drop policy if exists "product_images_auth_delete" on storage.objects;

create policy "product_images_public_read"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'product-images');

create policy "product_images_auth_insert"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'product-images');

create policy "product_images_auth_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'product-images')
with check (bucket_id = 'product-images');

create policy "product_images_auth_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'product-images');

-- ---------------------------------------------------------------------------
-- OWN COMPANIES: PDF issuer company cards
-- ---------------------------------------------------------------------------

create table if not exists public.own_companies (
  id text primary key,
  name text not null default '',
  short_name text not null default '',
  tagline text not null default '',
  phone text not null default '',
  email text not null default '',
  website text not null default '',
  address text not null default '',
  tax_office text not null default '',
  tax_number text not null default '',
  mersis text not null default '',
  bank_name text not null default '',
  bank_branch text not null default '',
  bank_account_name text not null default '',
  bank_iban text not null default '',
  bank_swift text not null default '',
  default_vat_rate numeric not null default 20,
  is_default boolean not null default false,
  updated_at timestamptz not null default now()
);

create unique index if not exists own_companies_single_default
on public.own_companies (is_default)
where is_default;

alter table public.own_companies enable row level security;

drop policy if exists "Authenticated users read own companies" on public.own_companies;
create policy "Authenticated users read own companies"
on public.own_companies
for select
to authenticated
using (true);

drop policy if exists "Managers manage own companies" on public.own_companies;
create policy "Managers manage own companies"
on public.own_companies
for all
to authenticated
using (public.is_quote_manager())
with check (public.is_quote_manager());
