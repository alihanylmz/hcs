begin;

update public.app_versions
set platform = lower(btrim(coalesce(platform, 'all')))
where platform is null
   or platform <> lower(btrim(platform));

update public.app_versions
set platform = 'all'
where platform = '';

delete from public.app_versions
where coalesce(btrim(version_name), '') = ''
   or build_number is null
   or build_number <= 0
   or coalesce(btrim(download_url), '') = '';

delete from public.app_versions
where platform not in ('all', 'android', 'windows');

with ranked_rows as (
  select
    id,
    row_number() over (
      partition by platform, build_number
      order by created_at desc nulls last, id desc
    ) as row_rank
  from public.app_versions
)
delete from public.app_versions av
using ranked_rows rr
where av.id = rr.id
  and rr.row_rank > 1;

alter table public.app_versions
  alter column version_name set not null,
  alter column build_number set not null,
  alter column download_url set not null;

alter table public.app_versions
  drop constraint if exists app_versions_platform_format_check,
  drop constraint if exists app_versions_platform_allowed_check,
  drop constraint if exists app_versions_version_name_nonempty_check,
  drop constraint if exists app_versions_build_number_positive_check,
  drop constraint if exists app_versions_download_url_nonempty_check;

alter table public.app_versions
  add constraint app_versions_platform_format_check
    check (platform = lower(btrim(platform))),
  add constraint app_versions_platform_allowed_check
    check (platform in ('all', 'android', 'windows')),
  add constraint app_versions_version_name_nonempty_check
    check (btrim(version_name) <> ''),
  add constraint app_versions_build_number_positive_check
    check (build_number > 0),
  add constraint app_versions_download_url_nonempty_check
    check (btrim(download_url) <> '');

drop index if exists idx_app_versions_platform_build;
create unique index if not exists idx_app_versions_platform_build
  on public.app_versions(platform, build_number desc);

commit;
