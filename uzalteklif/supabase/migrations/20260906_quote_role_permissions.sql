-- Faz 2.4: teklif paylaşımında görüntüleme, yorum, düzenleme ve onay ayrımı.
-- user_profiles mevcut rollerini korur: sales/seller, manager, finance, admin, viewer.
create table if not exists public.quote_collaborators (
  quote_id text not null references public.quotes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  can_view boolean not null default true,
  can_comment boolean not null default false,
  can_edit boolean not null default false,
  can_approve boolean not null default false,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (quote_id, user_id)
);

create table if not exists public.quote_comments (
  id uuid primary key default gen_random_uuid(),
  quote_id text not null references public.quotes(id) on delete cascade,
  author_user_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.quote_collaborators enable row level security;
alter table public.quote_comments enable row level security;

create or replace function public.can_view_quote_collaboration(p_quote_id text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.quote_collaborators c
    where c.quote_id = p_quote_id and c.user_id = auth.uid() and c.can_view
  ) or exists (
    select 1 from public.quotes q
    where q.id = p_quote_id and (q.created_by = auth.uid() or exists (
      select 1 from public.user_profiles u where u.user_id = auth.uid() and u.role in ('admin','manager','finance')
    ))
  );
$$;

drop policy if exists quote_collaborators_select on public.quote_collaborators;
create policy quote_collaborators_select on public.quote_collaborators for select to authenticated
using (user_id = auth.uid() or public.can_view_quote_collaboration(quote_id));

drop policy if exists quote_comments_select on public.quote_comments;
create policy quote_comments_select on public.quote_comments for select to authenticated
using (public.can_view_quote_collaboration(quote_id));

drop policy if exists quote_comments_insert on public.quote_comments;
create policy quote_comments_insert on public.quote_comments for insert to authenticated
with check (author_user_id = auth.uid() and public.can_view_quote_collaboration(quote_id));

grant execute on function public.can_view_quote_collaboration(text) to authenticated;
