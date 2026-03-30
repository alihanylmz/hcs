-- ============================================
-- TEAM WORKSPACE ALL-IN-ONE MIGRATION
-- Teams + Kanban + Knowledge Center + Conversations + Realtime
-- ============================================
-- Bunu Supabase SQL Editor'da tek parca olarak calistirabilirsiniz.
-- Mevcut sistem uzerine tekrar calistirilmasi genel olarak guvenlidir.
-- ============================================

create extension if not exists pgcrypto;

-- ============================================
-- 1) BASE TEAM / KANBAN TYPES
-- ============================================

do $$ begin
  create type team_role as enum ('owner', 'admin', 'member');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type card_status as enum ('TODO', 'DOING', 'DONE', 'SENT');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type card_event_type as enum (
    'CARD_CREATED',
    'STATUS_CHANGED',
    'ASSIGNEE_CHANGED',
    'UPDATED',
    'COMMENTED'
  );
exception
  when duplicate_object then null;
end $$;

-- ============================================
-- 2) BASE TEAM / KANBAN TABLES
-- ============================================

create table if not exists public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  emoji text not null default '🚀',
  accent_color text not null default '#2563EB',
  created_by uuid references auth.users(id) not null,
  created_at timestamptz default now()
);

alter table public.teams
  add column if not exists emoji text not null default '🚀';

alter table public.teams
  add column if not exists accent_color text not null default '#2563EB';

create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.teams(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role team_role not null default 'member',
  invited_by uuid references auth.users(id),
  joined_at timestamptz default now(),
  unique(team_id, user_id)
);

create table if not exists public.boards (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.teams(id) on delete cascade not null,
  name text not null,
  created_at timestamptz default now()
);

create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  board_id uuid references public.boards(id) on delete cascade not null,
  team_id uuid references public.teams(id) on delete cascade not null,
  title text not null,
  description text,
  status card_status not null default 'TODO',
  created_by uuid references auth.users(id) not null,
  assignee_id uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  first_doing_at timestamptz,
  done_at timestamptz,
  sent_at timestamptz
);

create table if not exists public.card_events (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.teams(id) on delete cascade not null,
  card_id uuid references public.cards(id) on delete cascade not null,
  user_id uuid references auth.users(id) not null,
  event_type card_event_type not null,
  from_status card_status,
  to_status card_status,
  from_assignee uuid references auth.users(id),
  to_assignee uuid references auth.users(id),
  created_at timestamptz default now()
);

create index if not exists idx_team_members_team_user
  on public.team_members(team_id, user_id);

create index if not exists idx_team_members_user
  on public.team_members(user_id);

create index if not exists idx_boards_team
  on public.boards(team_id);

create index if not exists idx_cards_team_status
  on public.cards(team_id, status);

create index if not exists idx_cards_board_status
  on public.cards(board_id, status);

create index if not exists idx_cards_assignee
  on public.cards(assignee_id);

create index if not exists idx_card_events_team_created
  on public.card_events(team_id, created_at);

create index if not exists idx_card_events_card_created
  on public.card_events(card_id, created_at);

alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.boards enable row level security;
alter table public.cards enable row level security;
alter table public.card_events enable row level security;

-- ============================================
-- 3) TEAM HELPER FUNCTIONS
-- ============================================

create or replace function public.is_team_member(
  p_team_id uuid,
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
stable
as $$
begin
  return exists (
    select 1
    from public.team_members
    where team_id = p_team_id
      and user_id = p_user_id
  );
end;
$$;

create or replace function public.get_team_role(
  p_team_id uuid,
  p_user_id uuid
)
returns team_role
language plpgsql
security definer
stable
as $$
declare
  v_role team_role;
begin
  select role
    into v_role
  from public.team_members
  where team_id = p_team_id
    and user_id = p_user_id;

  return v_role;
end;
$$;

create or replace function public.is_team_manager(
  target_team_id uuid,
  target_user_id uuid
)
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

create or replace function public.update_cards_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cards_updated_at_trigger on public.cards;
create trigger cards_updated_at_trigger
before update on public.cards
for each row
execute function public.update_cards_updated_at();

-- ============================================
-- 4) BASE TEAM / KANBAN RLS
-- ============================================

drop policy if exists teams_select_policy on public.teams;
create policy teams_select_policy
on public.teams
for select
using (
  created_by = auth.uid()
  or public.is_team_member(id, auth.uid())
);

drop policy if exists teams_insert_policy on public.teams;
create policy teams_insert_policy
on public.teams
for insert
with check (created_by = auth.uid());

drop policy if exists teams_update_policy on public.teams;
create policy teams_update_policy
on public.teams
for update
using (public.get_team_role(id, auth.uid()) = 'owner');

drop policy if exists teams_delete_policy on public.teams;
create policy teams_delete_policy
on public.teams
for delete
using (public.get_team_role(id, auth.uid()) = 'owner');

drop policy if exists team_members_select_policy on public.team_members;
create policy team_members_select_policy
on public.team_members
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_members_insert_policy on public.team_members;
create policy team_members_insert_policy
on public.team_members
for insert
with check (
  (user_id = auth.uid() and role = 'owner' and invited_by = auth.uid())
  or (
    exists (
      select 1
      from public.team_members tm
      where tm.team_id = team_members.team_id
        and tm.user_id = auth.uid()
        and tm.role in ('owner', 'admin')
    )
    and invited_by = auth.uid()
  )
);

drop policy if exists team_members_update_policy on public.team_members;
create policy team_members_update_policy
on public.team_members
for update
using (public.get_team_role(team_id, auth.uid()) = 'owner');

drop policy if exists team_members_delete_policy on public.team_members;
create policy team_members_delete_policy
on public.team_members
for delete
using (
  public.get_team_role(team_id, auth.uid()) in ('owner', 'admin')
  and role != 'owner'
);

drop policy if exists boards_select_policy on public.boards;
create policy boards_select_policy
on public.boards
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists boards_insert_policy on public.boards;
create policy boards_insert_policy
on public.boards
for insert
with check (public.is_team_member(team_id, auth.uid()));

drop policy if exists boards_update_policy on public.boards;
create policy boards_update_policy
on public.boards
for update
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists boards_delete_policy on public.boards;
create policy boards_delete_policy
on public.boards
for delete
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists cards_select_policy on public.cards;
create policy cards_select_policy
on public.cards
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists cards_insert_policy on public.cards;
create policy cards_insert_policy
on public.cards
for insert
with check (
  public.is_team_member(team_id, auth.uid())
  and created_by = auth.uid()
);

drop policy if exists cards_update_policy on public.cards;
create policy cards_update_policy
on public.cards
for update
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists cards_delete_policy on public.cards;
create policy cards_delete_policy
on public.cards
for delete
using (
  public.is_team_member(team_id, auth.uid())
  and (
    created_by = auth.uid()
    or public.get_team_role(team_id, auth.uid()) in ('owner', 'admin')
  )
);

drop policy if exists card_events_select_policy on public.card_events;
create policy card_events_select_policy
on public.card_events
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists card_events_insert_policy on public.card_events;
create policy card_events_insert_policy
on public.card_events
for insert
with check (
  public.is_team_member(team_id, auth.uid())
  and user_id = auth.uid()
);

-- ============================================
-- 5) KNOWLEDGE CENTER
-- ============================================

create table if not exists public.team_pages (
  id uuid primary key default gen_random_uuid(),
  team_id uuid references public.teams(id) on delete cascade not null,
  title text not null,
  summary text default '' not null,
  icon text default 'DOC' not null,
  created_by uuid references auth.users(id) not null,
  created_at timestamptz default now() not null,
  updated_at timestamptz default now() not null
);

create table if not exists public.team_page_blocks (
  id uuid primary key default gen_random_uuid(),
  page_id uuid references public.team_pages(id) on delete cascade not null,
  block_type text not null,
  sort_order integer default 0 not null,
  content jsonb default '{}'::jsonb not null,
  created_at timestamptz default now() not null
);

create index if not exists idx_team_pages_team_updated
  on public.team_pages(team_id, updated_at desc);

create index if not exists idx_team_page_blocks_page_order
  on public.team_page_blocks(page_id, sort_order);

alter table public.team_pages enable row level security;
alter table public.team_page_blocks enable row level security;

drop policy if exists team_pages_select_policy on public.team_pages;
create policy team_pages_select_policy
on public.team_pages
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_pages_insert_policy on public.team_pages;
create policy team_pages_insert_policy
on public.team_pages
for insert
with check (
  public.is_team_member(team_id, auth.uid())
  and created_by = auth.uid()
);

drop policy if exists team_pages_update_policy on public.team_pages;
create policy team_pages_update_policy
on public.team_pages
for update
using (public.is_team_member(team_id, auth.uid()))
with check (public.is_team_member(team_id, auth.uid()));

drop policy if exists team_pages_delete_policy on public.team_pages;
create policy team_pages_delete_policy
on public.team_pages
for delete
using (
  created_by = auth.uid()
  or public.get_team_role(team_id, auth.uid()) in ('owner', 'admin')
);

drop policy if exists team_page_blocks_select_policy on public.team_page_blocks;
create policy team_page_blocks_select_policy
on public.team_page_blocks
for select
using (
  exists (
    select 1
    from public.team_pages
    where public.team_pages.id = team_page_blocks.page_id
      and public.is_team_member(public.team_pages.team_id, auth.uid())
  )
);

drop policy if exists team_page_blocks_insert_policy on public.team_page_blocks;
create policy team_page_blocks_insert_policy
on public.team_page_blocks
for insert
with check (
  exists (
    select 1
    from public.team_pages
    where public.team_pages.id = team_page_blocks.page_id
      and public.is_team_member(public.team_pages.team_id, auth.uid())
  )
);

drop policy if exists team_page_blocks_update_policy on public.team_page_blocks;
create policy team_page_blocks_update_policy
on public.team_page_blocks
for update
using (
  exists (
    select 1
    from public.team_pages
    where public.team_pages.id = team_page_blocks.page_id
      and public.is_team_member(public.team_pages.team_id, auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.team_pages
    where public.team_pages.id = team_page_blocks.page_id
      and public.is_team_member(public.team_pages.team_id, auth.uid())
  )
);

drop policy if exists team_page_blocks_delete_policy on public.team_page_blocks;
create policy team_page_blocks_delete_policy
on public.team_page_blocks
for delete
using (
  exists (
    select 1
    from public.team_pages
    where public.team_pages.id = team_page_blocks.page_id
      and public.is_team_member(public.team_pages.team_id, auth.uid())
  )
);

create or replace function public.update_team_pages_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists team_pages_updated_at_trigger on public.team_pages;
create trigger team_pages_updated_at_trigger
before update on public.team_pages
for each row
execute function public.update_team_pages_updated_at();

-- ============================================
-- 6) CONVERSATIONS / THREADS
-- ============================================

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

create or replace function public.ensure_team_default_threads()
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

drop trigger if exists trg_ensure_team_default_threads on public.teams;
create trigger trg_ensure_team_default_threads
after insert on public.teams
for each row
execute function public.ensure_team_default_threads();

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

-- ============================================
-- 7) REALTIME PUBLICATION
-- ============================================

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      where p.pubname = 'supabase_realtime'
        and n.nspname = 'public'
        and c.relname = 'team_threads'
    ) then
      execute 'alter publication supabase_realtime add table public.team_threads';
    end if;

    if not exists (
      select 1
      from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      where p.pubname = 'supabase_realtime'
        and n.nspname = 'public'
        and c.relname = 'team_messages'
    ) then
      execute 'alter publication supabase_realtime add table public.team_messages';
    end if;

    if not exists (
      select 1
      from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      where p.pubname = 'supabase_realtime'
        and n.nspname = 'public'
        and c.relname = 'team_message_mentions'
    ) then
      execute 'alter publication supabase_realtime add table public.team_message_mentions';
    end if;

    if not exists (
      select 1
      from pg_publication_rel pr
      join pg_publication p on p.oid = pr.prpubid
      join pg_class c on c.oid = pr.prrelid
      join pg_namespace n on n.oid = c.relnamespace
      where p.pubname = 'supabase_realtime'
        and n.nspname = 'public'
        and c.relname = 'team_thread_reads'
    ) then
      execute 'alter publication supabase_realtime add table public.team_thread_reads';
    end if;
  end if;
end $$;

-- ============================================
-- 8) DONE
-- ============================================
-- Sonrasi icin hizli kontrol sorgulari:
--
-- select to_regclass('public.team_pages');
-- select to_regclass('public.team_page_blocks');
-- select to_regclass('public.team_threads');
-- select to_regclass('public.team_messages');
-- select to_regclass('public.team_message_mentions');
-- select to_regclass('public.team_thread_reads');
