-- ============================================
-- CARD NOTES + TICKET LINK
-- ============================================

alter table public.cards
  add column if not exists linked_ticket_id text;

create index if not exists idx_cards_linked_ticket_id
  on public.cards(linked_ticket_id)
  where linked_ticket_id is not null;

create table if not exists public.card_comments (
  id uuid primary key default gen_random_uuid(),
  card_id uuid references public.cards(id) on delete cascade not null,
  team_id uuid references public.teams(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  comment text not null,
  created_at timestamptz default now() not null
);

create index if not exists idx_card_comments_card
  on public.card_comments(card_id, created_at desc);

create index if not exists idx_card_comments_team
  on public.card_comments(team_id);

alter table public.card_comments enable row level security;

drop policy if exists card_comments_select_policy on public.card_comments;
create policy card_comments_select_policy
on public.card_comments
for select
using (public.is_team_member(team_id, auth.uid()));

drop policy if exists card_comments_insert_policy on public.card_comments;
create policy card_comments_insert_policy
on public.card_comments
for insert
with check (
  public.is_team_member(team_id, auth.uid())
  and user_id = auth.uid()
);

drop policy if exists card_comments_update_policy on public.card_comments;
create policy card_comments_update_policy
on public.card_comments
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists card_comments_delete_policy on public.card_comments;
create policy card_comments_delete_policy
on public.card_comments
for delete
using (
  user_id = auth.uid()
  or public.get_team_role(team_id, auth.uid()) in ('owner', 'admin')
);
