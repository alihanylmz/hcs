-- DDC kontrolör ve esnek I/O modülü kütüphanesi.
-- Önce .info/staging Supabase SQL Editor üzerinde çalıştırılmalıdır.

create table if not exists public.control_hardware_catalog (
  id text primary key,
  equipment_type text not null default 'controller',
  brand text not null,
  model text not null,
  family text not null default '',
  product_id text not null default '',
  channel_pools jsonb not null default '[]'::jsonb,
  compatibility_mode text not null default 'same_family',
  connection_protocol text not null default '',
  compatible_families jsonb not null default '[]'::jsonb,
  max_expansion_modules integer not null default 0,
  is_active boolean not null default true,
  note text not null default '',
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint control_hardware_type_check
    check (equipment_type in ('controller', 'io_module')),
  constraint control_hardware_max_modules_check
    check (max_expansion_modules >= 0)
);

create index if not exists control_hardware_brand_model_idx
on public.control_hardware_catalog (brand, model);

create index if not exists control_hardware_type_idx
on public.control_hardware_catalog (equipment_type, is_active);

alter table public.control_hardware_catalog enable row level security;

drop policy if exists "control_hardware_select_authenticated"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_insert_authenticated"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_update_scope"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_delete_scope"
on public.control_hardware_catalog;

create policy "control_hardware_select_authenticated"
on public.control_hardware_catalog
for select
to authenticated
using (true);

create policy "control_hardware_insert_authenticated"
on public.control_hardware_catalog
for insert
to authenticated
with check (
  created_by is null or created_by = auth.uid()
);

create policy "control_hardware_update_scope"
on public.control_hardware_catalog
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

create policy "control_hardware_delete_scope"
on public.control_hardware_catalog
for delete
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);
