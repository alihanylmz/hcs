-- ============================================
-- TAKIM KONUŞMALARI / THREAD SİSTEMİ
-- ============================================

create extension if not exists pgcrypto;

create table if not exists public.team_threads (
    id uuid primary key default gen_random_uuid(),
    team_id uuid not null references public.teams(id) on delete cascade,
    type text not null check (type in ('general', 'card', 'ticket', 'announcement')),
    title text not null,
    description text,
    card_id uuid references public.cards(id) on delete set null,
    ticket_id text,
    created_by uuid not null references auth.users(id) on delete cascade,
    is_pinned boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    last_message_at timestamptz not null default now()
);

alter table public.team_threads
    drop constraint if exists team_threads_ticket_id_fkey;

alter table public.team_threads
    alter column ticket_id type text using ticket_id::text;

create unique index if not exists idx_team_threads_unique_general
    on public.team_threads(team_id, type)
    where type = 'general';

create unique index if not exists idx_team_threads_unique_announcement
    on public.team_threads(team_id, type)
    where type = 'announcement';

create unique index if not exists idx_team_threads_unique_card
    on public.team_threads(team_id, card_id)
    where card_id is not null;

create unique index if not exists idx_team_threads_unique_ticket
    on public.team_threads(team_id, ticket_id)
    where ticket_id is not null;

create index if not exists idx_team_threads_team
    on public.team_threads(team_id, is_pinned desc, last_message_at desc);

create index if not exists idx_team_threads_card
    on public.team_threads(card_id)
    where card_id is not null;

create index if not exists idx_team_threads_ticket
    on public.team_threads(ticket_id)
    where ticket_id is not null;

create table if not exists public.team_messages (
    id uuid primary key default gen_random_uuid(),
    thread_id uuid not null references public.team_threads(id) on delete cascade,
    team_id uuid not null references public.teams(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    body text not null,
    message_type text not null default 'message' check (message_type in ('message', 'system')),
    reply_to_id uuid references public.team_messages(id) on delete set null,
    attachment_url text,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now()
);

create index if not exists idx_team_messages_thread
    on public.team_messages(thread_id, created_at asc);

create index if not exists idx_team_messages_team
    on public.team_messages(team_id, created_at desc);

create table if not exists public.team_message_mentions (
    id bigserial primary key,
    message_id uuid not null references public.team_messages(id) on delete cascade,
    thread_id uuid not null references public.team_threads(id) on delete cascade,
    team_id uuid not null references public.teams(id) on delete cascade,
    mentioned_user_id uuid not null references auth.users(id) on delete cascade,
    created_at timestamptz not null default now(),
    unique(message_id, mentioned_user_id)
);

create index if not exists idx_team_message_mentions_user
    on public.team_message_mentions(mentioned_user_id, created_at desc);

create table if not exists public.team_thread_reads (
    thread_id uuid not null references public.team_threads(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    last_read_message_id uuid references public.team_messages(id) on delete set null,
    last_read_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    primary key (thread_id, user_id)
);

create index if not exists idx_team_thread_reads_user
    on public.team_thread_reads(user_id, updated_at desc);

create or replace function public.is_team_member(target_team_id uuid, target_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = target_team_id
      and tm.user_id = target_user_id
  );
$$;

create or replace function public.is_team_manager(target_team_id uuid, target_user_id uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from public.team_members tm
    where tm.team_id = target_team_id
      and tm.user_id = target_user_id
      and tm.role in ('owner', 'admin')
  );
$$;

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

create or replace function public.set_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.touch_team_thread_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.team_threads
     set last_message_at = new.created_at,
         updated_at = now()
   where id = new.thread_id;

  return new;
end;
$$;

create or replace function public.ensure_team_general_thread()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
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
$$;

drop trigger if exists trg_team_threads_updated_at on public.team_threads;
create trigger trg_team_threads_updated_at
before update on public.team_threads
for each row
execute function public.set_timestamp();

drop trigger if exists trg_team_thread_reads_updated_at on public.team_thread_reads;
create trigger trg_team_thread_reads_updated_at
before update on public.team_thread_reads
for each row
execute function public.set_timestamp();

drop trigger if exists trg_touch_team_thread_activity on public.team_messages;
create trigger trg_touch_team_thread_activity
after insert on public.team_messages
for each row
execute function public.touch_team_thread_activity();

drop trigger if exists trg_ensure_team_general_thread on public.teams;
create trigger trg_ensure_team_general_thread
after insert on public.teams
for each row
execute function public.ensure_team_general_thread();

insert into public.team_threads (
    team_id,
    type,
    title,
    description,
    created_by,
    is_pinned
)
select
    t.id,
    'general',
    'Genel',
    'Takim ici genel konusmalar burada toplanir.',
    t.created_by,
    true
from public.teams t
where not exists (
    select 1
    from public.team_threads tt
    where tt.team_id = t.id
      and tt.type = 'general'
);

insert into public.team_threads (
    team_id,
    type,
    title,
    description,
    created_by,
    is_pinned
)
select
    t.id,
    'announcement',
    'Duyurular',
    'Takim duyurulari ve resmi bilgilendirmeler burada tutulur.',
    t.created_by,
    true
from public.teams t
where not exists (
    select 1
    from public.team_threads tt
    where tt.team_id = t.id
      and tt.type = 'announcement'
);

alter table public.team_threads enable row level security;
alter table public.team_messages enable row level security;
alter table public.team_message_mentions enable row level security;
alter table public.team_thread_reads enable row level security;

drop policy if exists team_threads_select_policy on public.team_threads;
create policy team_threads_select_policy
on public.team_threads
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_threads_insert_policy on public.team_threads;
create policy team_threads_insert_policy
on public.team_threads
for insert
with check (
    public.is_team_manager(team_id, auth.uid())
    and created_by = auth.uid()
);

drop policy if exists team_threads_update_policy on public.team_threads;
create policy team_threads_update_policy
on public.team_threads
for update
using (
    public.is_team_manager(team_id, auth.uid())
    or created_by = auth.uid()
)
with check (
    public.is_team_manager(team_id, auth.uid())
    or created_by = auth.uid()
);

drop policy if exists team_threads_delete_policy on public.team_threads;
create policy team_threads_delete_policy
on public.team_threads
for delete
using (
    public.is_team_manager(team_id, auth.uid())
    or created_by = auth.uid()
);

drop policy if exists team_messages_select_policy on public.team_messages;
create policy team_messages_select_policy
on public.team_messages
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_messages_insert_policy on public.team_messages;
create policy team_messages_insert_policy
on public.team_messages
for insert
with check (
    public.is_team_member(team_id, auth.uid())
    and user_id = auth.uid()
);

drop policy if exists team_messages_update_policy on public.team_messages;
create policy team_messages_update_policy
on public.team_messages
for update
using (
    user_id = auth.uid()
    or public.is_team_manager(team_id, auth.uid())
)
with check (
    user_id = auth.uid()
    or public.is_team_manager(team_id, auth.uid())
);

drop policy if exists team_messages_delete_policy on public.team_messages;
create policy team_messages_delete_policy
on public.team_messages
for delete
using (
    user_id = auth.uid()
    or public.is_team_manager(team_id, auth.uid())
);

drop policy if exists team_message_mentions_select_policy on public.team_message_mentions;
create policy team_message_mentions_select_policy
on public.team_message_mentions
for select
using (
    mentioned_user_id = auth.uid()
    or public.is_team_manager(team_id, auth.uid())
);

drop policy if exists team_message_mentions_insert_policy on public.team_message_mentions;
create policy team_message_mentions_insert_policy
on public.team_message_mentions
for insert
with check (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_thread_reads_select_policy on public.team_thread_reads;
create policy team_thread_reads_select_policy
on public.team_thread_reads
for select
using (user_id = auth.uid());

drop policy if exists team_thread_reads_insert_policy on public.team_thread_reads;
create policy team_thread_reads_insert_policy
on public.team_thread_reads
for insert
with check (user_id = auth.uid());

drop policy if exists team_thread_reads_update_policy on public.team_thread_reads;
create policy team_thread_reads_update_policy
on public.team_thread_reads
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());
