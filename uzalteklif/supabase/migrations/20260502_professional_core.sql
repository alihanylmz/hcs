-- Professional core hardening:
-- - Brand/category price adjustment rules
-- - Audit log
-- - Quote revision snapshots
--
-- This migration is intentionally idempotent so it can be applied after the
-- older schema.sql without dropping live data.

create extension if not exists "pgcrypto";

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
  item_description text;
  item_quantity numeric;
  item_unit_price numeric;
  item_discount numeric;
begin
  delete from public.quote_line_items where quote_id = new.id;

  for item in select * from jsonb_array_elements(coalesce(new.items, '[]'::jsonb))
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
      new.id || ':' || item_id,
      new.id,
      split_part(item_description, ' - ', 1),
      item_description,
      item_quantity,
      coalesce(item->>'unit', ''),
      item_unit_price,
      item_discount,
      coalesce(item->>'section_id', ''),
      item_quantity * item_unit_price * (1 - (item_discount / 100))
    );
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

alter table public.price_adjustment_rules enable row level security;
alter table public.audit_logs enable row level security;
alter table public.quote_revisions enable row level security;
alter table public.quote_line_items enable row level security;

drop policy if exists "Managers manage price adjustment rules" on public.price_adjustment_rules;
drop policy if exists "Authenticated read price adjustment rules" on public.price_adjustment_rules;
drop policy if exists "Managers read audit logs" on public.audit_logs;
drop policy if exists "Managers read quote revisions" on public.quote_revisions;
drop policy if exists "quote_line_items_select_scope" on public.quote_line_items;

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
