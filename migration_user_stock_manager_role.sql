begin;

alter table public.user_app_access
drop constraint if exists user_app_access_is_takip_role_check;

alter table public.user_app_access
add constraint user_app_access_is_takip_role_check
check (
  app_code <> 'is_takip'
  or app_role in (
    'admin',
    'manager',
    'stock_manager',
    'supervisor',
    'engineer',
    'technician',
    'user',
    'partner_user',
    'pending'
  )
) not valid;

create or replace function public.manage_user_access(
  p_user_id uuid,
  p_is_takip_active boolean,
  p_is_takip_role text,
  p_teklif_active boolean,
  p_teklif_role text,
  p_partner_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_target_quote_role text;
  v_old_access jsonb;
  v_new_access jsonb;
  v_active_admin_count integer;
begin
  select role::text into v_actor_role
  from public.profiles
  where id = v_actor_id;

  if v_actor_role <> 'admin' then
    raise exception 'Bu islem icin kullanici yonetimi yetkiniz yok.';
  end if;

  select role::text into v_target_role
  from public.profiles
  where id = p_user_id;

  if v_target_role is null then
    raise exception 'Kullanici profili bulunamadi.';
  end if;

  select app_role into v_target_quote_role
  from public.user_app_access
  where user_id = p_user_id
    and app_code = 'teklif';

  if p_is_takip_role not in (
    'admin', 'manager', 'stock_manager', 'supervisor', 'engineer',
    'technician', 'user', 'partner_user'
  ) then
    raise exception 'Gecersiz Is Takip rolu.';
  end if;

  if p_teklif_role not in (
    'admin', 'manager', 'sales', 'finance', 'operations', 'viewer'
  ) then
    raise exception 'Gecersiz Teklif rolu.';
  end if;

  if p_is_takip_active
     and p_is_takip_role = 'partner_user'
     and p_partner_id is null then
    raise exception 'Partner kullanici icin firma secilmelidir.';
  end if;

  if v_actor_role = 'manager'
     and (
       v_target_role = 'admin'
       or p_is_takip_role = 'admin'
       or v_target_quote_role = 'admin'
       or p_teklif_role = 'admin'
     ) then
    raise exception 'Yonetici, sistem yoneticisi hesabini degistiremez veya atayamaz.';
  end if;

  if p_user_id = v_actor_id
     and (
       not p_is_takip_active
       or p_is_takip_role <> 'admin'
       or not p_teklif_active
       or p_teklif_role <> 'admin'
     ) then
    raise exception 'Genel Mudur kendi erisimini kapatamaz veya tam yetkisini dusuremez.';
  end if;

  if v_target_role = 'admin'
     and (not p_is_takip_active or p_is_takip_role <> 'admin') then
    select count(*) into v_active_admin_count
    from public.user_app_access
    where app_code = 'is_takip'
      and app_role = 'admin'
      and is_active;

    if v_active_admin_count <= 1 then
      raise exception 'Sistemde en az bir aktif sistem yoneticisi kalmalidir.';
    end if;
  end if;

  select coalesce(jsonb_object_agg(app_code, jsonb_build_object(
    'role', app_role,
    'active', is_active
  )), '{}'::jsonb)
  into v_old_access
  from public.user_app_access
  where user_id = p_user_id;

  update public.profiles
  set
    role = case when p_is_takip_active then p_is_takip_role else 'pending' end,
    partner_id = case
      when p_is_takip_active and p_is_takip_role = 'partner_user'
        then p_partner_id
      else null
    end,
    updated_at = now()
  where id = p_user_id;

  insert into public.user_app_access (
    user_id, app_code, app_role, is_active, granted_by, granted_at, updated_at
  ) values (
    p_user_id, 'is_takip', p_is_takip_role, p_is_takip_active,
    v_actor_id, now(), now()
  )
  on conflict (user_id, app_code) do update
  set
    app_role = excluded.app_role,
    is_active = excluded.is_active,
    granted_by = excluded.granted_by,
    updated_at = now();

  insert into public.user_app_access (
    user_id, app_code, app_role, is_active, granted_by, granted_at, updated_at
  ) values (
    p_user_id, 'teklif', p_teklif_role, p_teklif_active,
    v_actor_id, now(), now()
  )
  on conflict (user_id, app_code) do update
  set
    app_role = excluded.app_role,
    is_active = excluded.is_active,
    granted_by = excluded.granted_by,
    updated_at = now();

  select jsonb_object_agg(app_code, jsonb_build_object(
    'role', app_role,
    'active', is_active
  ))
  into v_new_access
  from public.user_app_access
  where user_id = p_user_id;

  insert into public.user_access_audit_logs (
    actor_user_id,
    target_user_id,
    old_access,
    new_access
  ) values (
    v_actor_id,
    p_user_id,
    v_old_access,
    coalesce(v_new_access, '{}'::jsonb)
  );

  return jsonb_build_object(
    'user_id', p_user_id,
    'is_takip_active', p_is_takip_active,
    'is_takip_role', p_is_takip_role,
    'teklif_active', p_teklif_active,
    'teklif_role', p_teklif_role
  );
end;
$$;

commit;
