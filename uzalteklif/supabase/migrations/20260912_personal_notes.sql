-- Calisma Masasi: ajanda / not defteri / hatirlatici kayitlari.
-- Her kullanici yalnizca kendi kayitlarini gorur ve degistirir.

create table if not exists public.personal_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default '',
  body text not null default '',
  note_date date,
  is_reminder boolean not null default false,
  is_done boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists personal_notes_user_id_idx
  on public.personal_notes (user_id);

create index if not exists personal_notes_user_date_idx
  on public.personal_notes (user_id, note_date);

create or replace function public.set_personal_notes_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_personal_notes_updated_at on public.personal_notes;
create trigger trg_personal_notes_updated_at
  before update on public.personal_notes
  for each row execute function public.set_personal_notes_updated_at();

alter table public.personal_notes enable row level security;

drop policy if exists "personal_notes_select_own" on public.personal_notes;
create policy "personal_notes_select_own"
  on public.personal_notes for select
  using (auth.uid() = user_id);

drop policy if exists "personal_notes_insert_own" on public.personal_notes;
create policy "personal_notes_insert_own"
  on public.personal_notes for insert
  with check (auth.uid() = user_id);

drop policy if exists "personal_notes_update_own" on public.personal_notes;
create policy "personal_notes_update_own"
  on public.personal_notes for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "personal_notes_delete_own" on public.personal_notes;
create policy "personal_notes_delete_own"
  on public.personal_notes for delete
  using (auth.uid() = user_id);
