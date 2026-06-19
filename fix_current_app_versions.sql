begin;

delete from public.app_versions
where platform in ('android', 'windows');

insert into public.app_versions (
  platform,
  version_name,
  build_number,
  download_url,
  release_notes,
  github_tag,
  is_mandatory
) values
  (
    'android',
    '1.1.10',
    15,
    'https://github.com/alihanylmz/hcs/releases/download/v1.1.10/istakip-android-v1.1.10+15.apk',
    'Android release',
    'v1.1.10',
    false
  ),
  (
    'windows',
    '1.1.10',
    15,
    'https://github.com/alihanylmz/hcs/releases/latest/download/istakip-windows-setup.exe',
    'Windows installer release',
    'v1.1.10',
    false
  );

commit;
