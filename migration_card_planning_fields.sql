alter table public.cards
  add column if not exists priority text not null default 'normal',
  add column if not exists due_date timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'cards_priority_check'
  ) then
    alter table public.cards
      add constraint cards_priority_check
      check (priority in ('low', 'normal', 'high'));
  end if;
end $$;

create index if not exists idx_cards_priority on public.cards(priority);
create index if not exists idx_cards_due_date on public.cards(due_date);

update public.cards
set priority = 'normal'
where priority is null;
