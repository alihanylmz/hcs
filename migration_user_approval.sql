-- Admin / manager onay akisi
-- Supabase SQL Editor'da bir kez calistir.

create or replace function public.approve_user_account(
  p_user_id uuid,
  p_role text,
  p_partner_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_actor_role text;
  v_target_user auth.users%rowtype;
begin
  select role
  into v_actor_role
  from public.profiles
  where id = auth.uid();

  if v_actor_role not in ('admin', 'manager') then
    raise exception 'Bu islem icin yetkiniz yok.';
  end if;

  if p_role not in (
    'admin',
    'manager',
    'supervisor',
    'engineer',
    'technician',
    'user',
    'partner_user',
    'pending'
  ) then
    raise exception 'Gecersiz rol secimi.';
  end if;

  if p_role = 'partner_user' and p_partner_id is null then
    raise exception 'Partner kullanicisi icin partner secilmelidir.';
  end if;

  select *
  into v_target_user
  from auth.users
  where id = p_user_id;

  if v_target_user.id is null then
    raise exception 'Auth kullanicisi bulunamadi.';
  end if;

  insert into public.profiles (
    id,
    email,
    full_name,
    role,
    partner_id
  )
  values (
    v_target_user.id,
    v_target_user.email,
    coalesce(
      v_target_user.raw_user_meta_data->>'full_name',
      v_target_user.raw_user_meta_data->>'name',
      v_target_user.email
    ),
    p_role,
    case when p_role = 'partner_user' then p_partner_id else null end
  )
  on conflict (id) do update
  set
    email = excluded.email,
    full_name = coalesce(public.profiles.full_name, excluded.full_name),
    role = excluded.role,
    partner_id = excluded.partner_id,
    updated_at = now();

  if p_role <> 'pending' then
    update auth.users
    set
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      confirmed_at = coalesce(confirmed_at, now()),
      updated_at = now()
    where id = p_user_id;
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'role', p_role,
    'email_confirmed', p_role <> 'pending'
  );
end;
$$;

revoke all on function public.approve_user_account(uuid, text, bigint) from public;
grant execute on function public.approve_user_account(uuid, text, bigint) to authenticated;
