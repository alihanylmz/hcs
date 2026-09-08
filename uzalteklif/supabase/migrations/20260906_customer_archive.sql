alter table public.customer_accounts
  add column if not exists archived_at timestamptz,
  add column if not exists is_active boolean not null default true;

create index if not exists customer_accounts_is_active_idx
  on public.customer_accounts (is_active);
