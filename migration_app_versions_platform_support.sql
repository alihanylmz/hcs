create table if not exists public.app_versions (
  id bigserial primary key,
  platform text not null default 'all',
  version_name text not null,
  build_number integer not null,
  download_url text not null,
  release_notes text,
  github_tag text,
  is_mandatory boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.app_versions
  add column if not exists platform text not null default 'all',
  add column if not exists version_name text,
  add column if not exists build_number integer,
  add column if not exists download_url text,
  add column if not exists release_notes text,
  add column if not exists github_tag text,
  add column if not exists is_mandatory boolean not null default false,
  add column if not exists created_at timestamptz not null default now();

update public.app_versions
set platform = coalesce(nullif(platform, ''), 'all')
where platform is null
   or btrim(platform) = '';

create index if not exists idx_app_versions_platform_build
  on public.app_versions(platform, build_number desc);

alter table public.app_versions enable row level security;

drop policy if exists app_versions_read_policy on public.app_versions;
create policy app_versions_read_policy on public.app_versions
  for select
  to authenticated
  using (true);
