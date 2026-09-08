-- Faz 2.2: teklif sahipliği, takip tarihleri ve kayıp nedeni.
alter table public.quotes
  add column if not exists owner_user_id uuid references auth.users(id) on delete set null,
  add column if not exists valid_until date,
  add column if not exists next_action_at timestamptz,
  add column if not exists expected_close_at date,
  add column if not exists loss_reason_code text not null default '',
  add column if not exists status_changed_at timestamptz,
  add column if not exists archived_at timestamptz;

-- Önce kopuk cari ilişkilerini raporla; kayıtlar silinmez.
create table if not exists public.quote_cari_orphans_20260906 (
  quote_id text primary key,
  cari_id text not null,
  detected_at timestamptz not null default timezone('utc', now())
);

insert into public.quote_cari_orphans_20260906 (quote_id, cari_id)
select q.id, q.cari_id
from public.quotes q
left join public.customer_accounts c on c.id = q.cari_id
where nullif(trim(q.cari_id), '') is not null
  and c.id is null
on conflict (quote_id) do nothing;

-- Manuel müşteri girilen teklifler cari bağlantısı olmadan yaşayabilir.
alter table public.quotes alter column cari_id drop not null;
-- Boş cari kimlikleri ilişkisel olarak NULL olmalıdır.
update public.quotes set cari_id = null where nullif(trim(cari_id), '') is null;

-- Mevcut kopuk kayıtları engellemeden FK'yi devreye alır.
alter table public.quotes drop constraint if exists quotes_cari_id_fkey;
alter table public.quotes
  add constraint quotes_cari_id_fkey
  foreign key (cari_id) references public.customer_accounts(id)
  on delete set null not valid;

create index if not exists quotes_owner_user_id_idx on public.quotes (owner_user_id);
create index if not exists quotes_next_action_at_idx on public.quotes (next_action_at);
create index if not exists quotes_valid_until_idx on public.quotes (valid_until);
