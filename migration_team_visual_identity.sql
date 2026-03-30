-- ============================================
-- TEAM VISUAL IDENTITY
-- Emoji + accent color for team cards
-- ============================================

alter table public.teams
  add column if not exists emoji text;

alter table public.teams
  add column if not exists accent_color text;

update public.teams
set emoji = coalesce(nullif(btrim(emoji), ''), '🚀');

update public.teams
set accent_color = case
  when accent_color is null or btrim(accent_color) = '' then '#2563EB'
  when upper(btrim(accent_color)) ~ '^#[0-9A-F]{6}$' then upper(btrim(accent_color))
  else '#2563EB'
end;

alter table public.teams
  alter column emoji set default '🚀';

alter table public.teams
  alter column accent_color set default '#2563EB';

alter table public.teams
  alter column emoji set not null;

alter table public.teams
  alter column accent_color set not null;

alter table public.teams
  drop constraint if exists teams_accent_color_hex_check;

alter table public.teams
  add constraint teams_accent_color_hex_check
  check (accent_color ~ '^#[0-9A-F]{6}$');
