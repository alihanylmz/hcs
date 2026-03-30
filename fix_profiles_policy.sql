-- ============================================
-- PROFILES ACCESS HARDENING + TEAM INVITE RPC
-- ============================================

alter table public.profiles enable row level security;

create or replace function public.can_manage_profiles(p_actor_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles actor
    where actor.id = p_actor_id
      and actor.role in ('admin', 'manager')
  );
$$;

grant execute on function public.can_manage_profiles(uuid) to authenticated;

create or replace function public.can_read_profile(p_profile_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select auth.uid() is not null and (
    p_profile_id = auth.uid()
    or public.can_manage_profiles(auth.uid())
    or exists (
      select 1
      from public.team_members my_tm
      join public.team_members target_tm
        on target_tm.team_id = my_tm.team_id
      where my_tm.user_id = auth.uid()
        and target_tm.user_id = p_profile_id
    )
  );
$$;

grant execute on function public.can_read_profile(uuid) to authenticated;

create or replace function public.list_team_invitable_profiles(p_team_id uuid)
returns table (
  id uuid,
  email text,
  full_name text,
  role text,
  partner_id bigint,
  signature_data text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Kullanici oturumu bulunamadi.';
  end if;

  if not public.is_team_manager(p_team_id, v_user_id) then
    raise exception 'Bu takim icin uye davet listesine erisim yetkiniz yok.';
  end if;

  return query
  select
    p.id,
    p.email,
    p.full_name,
    p.role,
    p.partner_id::bigint,
    p.signature_data,
    p.created_at
  from public.profiles p
  where p.role <> 'pending'
  order by lower(coalesce(nullif(btrim(p.full_name), ''), p.email, p.id::text));
end;
$$;

grant execute on function public.list_team_invitable_profiles(uuid) to authenticated;

drop policy if exists profiles_select_policy on public.profiles;
create policy profiles_select_policy on public.profiles
  for select
  using (public.can_read_profile(id));

drop policy if exists profiles_update_policy on public.profiles;
create policy profiles_update_policy on public.profiles
  for update
  using (
    id = auth.uid()
    or public.can_manage_profiles(auth.uid())
  )
  with check (
    id = auth.uid()
    or public.can_manage_profiles(auth.uid())
  );

drop policy if exists profiles_insert_policy on public.profiles;
create policy profiles_insert_policy on public.profiles
  for insert
  with check (id = auth.uid());
