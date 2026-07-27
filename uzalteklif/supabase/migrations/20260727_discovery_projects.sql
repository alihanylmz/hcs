-- Keşif ve otomasyon nokta analizi kayıtları.
-- Önce .info/staging Supabase SQL Editor üzerinde çalıştırılmalıdır.

create table if not exists public.discovery_projects (
  id text primary key,
  project_name text not null,
  project_code text not null default '',
  revision text not null default '00',
  prepared_by text not null default '',
  devices jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists discovery_projects_updated_at_idx
on public.discovery_projects (updated_at desc);

create index if not exists discovery_projects_created_by_idx
on public.discovery_projects (created_by);

alter table public.discovery_projects enable row level security;

drop policy if exists "discovery_projects_select_scope"
on public.discovery_projects;
drop policy if exists "discovery_projects_insert_authenticated"
on public.discovery_projects;
drop policy if exists "discovery_projects_update_scope"
on public.discovery_projects;
drop policy if exists "discovery_projects_delete_scope"
on public.discovery_projects;

create policy "discovery_projects_select_scope"
on public.discovery_projects
for select
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);

create policy "discovery_projects_insert_authenticated"
on public.discovery_projects
for insert
to authenticated
with check (
  created_by is null or created_by = auth.uid()
);

create policy "discovery_projects_update_scope"
on public.discovery_projects
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

create policy "discovery_projects_delete_scope"
on public.discovery_projects
for delete
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);
