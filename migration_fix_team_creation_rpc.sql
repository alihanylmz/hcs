-- ============================================
-- TEAM CREATION / CONVERSATION TRIGGER FIX
-- ============================================
-- Bu dosya mevcut Supabase kurulumlarinda:
-- 1) Takim olusturmayi tek transaction icinde yapan RPC ekler.
-- 2) Konusma trigger'larini SECURITY DEFINER yaparak RLS kaynakli
--    takim olusturma ve mesajlasma hatalarini engeller.

create or replace function public.create_team_with_owner(
  p_name text,
  p_description text default null
)
returns public.teams
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_team public.teams%rowtype;
  v_name text := btrim(coalesce(p_name, ''));
  v_description text := nullif(btrim(coalesce(p_description, '')), '');
begin
  if v_user_id is null then
    raise exception 'Kullanici oturumu bulunamadi.';
  end if;

  if v_name = '' then
    raise exception 'Takim adi zorunludur.';
  end if;

  insert into public.teams (
    name,
    description,
    created_by
  )
  values (
    v_name,
    v_description,
    v_user_id
  )
  returning *
    into v_team;

  insert into public.team_members (
    team_id,
    user_id,
    role,
    invited_by
  )
  values (
    v_team.id,
    v_user_id,
    'owner',
    v_user_id
  )
  on conflict (team_id, user_id) do update
    set role = excluded.role,
        invited_by = excluded.invited_by;

  return v_team;
end;
$$;

grant execute on function public.create_team_with_owner(text, text) to authenticated;

do $$
begin
  if to_regclass('public.team_threads') is not null
     and to_regclass('public.teams') is not null then
    execute $fn$
      create or replace function public.ensure_team_general_thread()
      returns trigger
      language plpgsql
      security definer
      set search_path = public
      as $body$
      begin
        insert into public.team_threads (
          team_id,
          type,
          title,
          description,
          created_by,
          is_pinned
        )
        values (
          new.id,
          'general',
          'Genel',
          'Takim ici genel konusmalar burada toplanir.',
          new.created_by,
          true
        )
        on conflict do nothing;

        insert into public.team_threads (
          team_id,
          type,
          title,
          description,
          created_by,
          is_pinned
        )
        values (
          new.id,
          'announcement',
          'Duyurular',
          'Takim duyurulari ve resmi bilgilendirmeler burada tutulur.',
          new.created_by,
          true
        )
        on conflict do nothing;

        return new;
      end;
      $body$;
    $fn$;
  end if;
end
$$;

do $$
begin
  if to_regclass('public.team_threads') is not null
     and to_regclass('public.teams') is not null then
    execute $fn$
      create or replace function public.ensure_team_default_threads()
      returns trigger
      language plpgsql
      security definer
      set search_path = public
      as $body$
      begin
        insert into public.team_threads (
          team_id,
          type,
          title,
          description,
          created_by,
          is_pinned
        )
        values (
          new.id,
          'general',
          'Genel',
          'Takim ici genel konusmalar burada toplanir.',
          new.created_by,
          true
        )
        on conflict do nothing;

        insert into public.team_threads (
          team_id,
          type,
          title,
          description,
          created_by,
          is_pinned
        )
        values (
          new.id,
          'announcement',
          'Duyurular',
          'Takim duyurulari ve resmi bilgilendirmeler burada tutulur.',
          new.created_by,
          true
        )
        on conflict do nothing;

        return new;
      end;
      $body$;
    $fn$;
  end if;
end
$$;

do $$
begin
  if to_regclass('public.team_threads') is not null
     and to_regclass('public.team_messages') is not null then
    execute $fn$
      create or replace function public.touch_team_thread_activity()
      returns trigger
      language plpgsql
      security definer
      set search_path = public
      as $body$
      begin
        update public.team_threads
           set last_message_at = new.created_at,
               updated_at = now()
         where id = new.thread_id;

        return new;
      end;
      $body$;
    $fn$;
  end if;
end
$$;
