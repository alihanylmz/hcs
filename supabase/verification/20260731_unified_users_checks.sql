-- 20260731_unified_users.sql uygulandıktan sonra hedef İş Takip projesinde
-- Supabase SQL Editor üzerinden salt-okunur kontrol amacıyla çalıştırılabilir.
-- Bu dosya hiçbir veriyi değiştirmez.

select
  to_regclass('public.user_app_access') is not null as user_app_access_ready,
  to_regclass('public.user_quote_settings') is not null as user_quote_settings_ready,
  to_regclass('public.auth_user_migration_map') is not null as migration_map_ready,
  to_regclass('public.quote_user_profiles') is not null as quote_profile_view_ready;

select
  app_code,
  count(*) as user_count,
  count(*) filter (where is_active) as active_user_count
from public.user_app_access
group by app_code
order by app_code;

select
  count(*) as profile_count,
  count(*) filter (
    where exists (
      select 1
      from public.user_app_access access
      where access.user_id = profiles.id
        and access.app_code = 'is_takip'
    )
  ) as profiles_with_is_takip_access
from public.profiles;

select
  source_system,
  migration_status,
  count(*) as user_count
from public.auth_user_migration_map
group by source_system, migration_status
order by source_system, migration_status;
