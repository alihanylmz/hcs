-- Keşif panoları için kontrolör/Remote I/O topoloji tercihleri.

alter table public.discovery_projects
add column if not exists panel_settings jsonb not null default '[]'::jsonb;
