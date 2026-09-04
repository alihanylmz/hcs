-- Teklif kaydinda son kaydedenin diger kullanicinin degisikliklerini ezmesini
-- engellemek icin guncelleme zaman damgasi eklenir.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

alter table public.quotes
add column if not exists updated_at timestamptz not null default timezone('utc', now());

create index if not exists quotes_updated_at_idx
on public.quotes (updated_at desc);

drop trigger if exists quotes_set_updated_at on public.quotes;
create trigger quotes_set_updated_at
before update on public.quotes
for each row
execute function public.set_updated_at();
