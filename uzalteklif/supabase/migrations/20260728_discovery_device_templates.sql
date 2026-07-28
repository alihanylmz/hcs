create table if not exists public.discovery_device_templates (
  id text primary key,
  name text not null,
  category_name text not null default 'Özel Cihazlar',
  points jsonb not null default '[]'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

alter table public.discovery_device_templates enable row level security;

drop policy if exists "Authenticated users can read discovery device templates"
  on public.discovery_device_templates;
create policy "Authenticated users can read discovery device templates"
  on public.discovery_device_templates
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users can create discovery device templates"
  on public.discovery_device_templates;
create policy "Authenticated users can create discovery device templates"
  on public.discovery_device_templates
  for insert
  to authenticated
  with check (created_by = auth.uid());

drop policy if exists "Creators can update discovery device templates"
  on public.discovery_device_templates;
create policy "Creators can update discovery device templates"
  on public.discovery_device_templates
  for update
  to authenticated
  using (created_by = auth.uid())
  with check (created_by = auth.uid());

drop policy if exists "Creators can delete discovery device templates"
  on public.discovery_device_templates;
create policy "Creators can delete discovery device templates"
  on public.discovery_device_templates
  for delete
  to authenticated
  using (created_by = auth.uid());
