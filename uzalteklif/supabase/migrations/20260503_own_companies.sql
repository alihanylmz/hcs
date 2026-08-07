create table if not exists public.own_companies (
  id text primary key,
  name text not null default '',
  short_name text not null default '',
  tagline text not null default '',
  phone text not null default '',
  email text not null default '',
  website text not null default '',
  address text not null default '',
  tax_office text not null default '',
  tax_number text not null default '',
  mersis text not null default '',
  bank_name text not null default '',
  bank_branch text not null default '',
  bank_account_name text not null default '',
  bank_iban text not null default '',
  bank_swift text not null default '',
  default_vat_rate numeric not null default 20,
  is_default boolean not null default false,
  updated_at timestamptz not null default now()
);

create unique index if not exists own_companies_single_default
on public.own_companies (is_default)
where is_default;

alter table public.own_companies enable row level security;

drop policy if exists "Authenticated users read own companies" on public.own_companies;
create policy "Authenticated users read own companies"
on public.own_companies
for select
to authenticated
using (true);

drop policy if exists "Managers manage own companies" on public.own_companies;
create policy "Managers manage own companies"
on public.own_companies
for all
to authenticated
using (public.is_quote_manager())
with check (public.is_quote_manager());

insert into public.own_companies (
  id,
  name,
  short_name,
  tagline,
  phone,
  email,
  website,
  address,
  tax_office,
  tax_number,
  mersis,
  bank_name,
  bank_branch,
  bank_account_name,
  bank_iban,
  bank_swift,
  default_vat_rate,
  is_default
)
values (
  'default-company',
  'UZAL TEKNIK MUHENDISLIK LTD. STI.',
  'UZAL TEKNIK',
  'Endustriyel Otomasyon ve Mekanik Cozumler',
  '+90 216 555 34 78',
  'teklif@uzalteknik.com.tr',
  'www.uzalteknik.com.tr',
  'Dudullu OSB Mah. 3. Cadde No:12 Kat:2 Umraniye / Istanbul',
  'Umraniye Vergi Dairesi',
  '1234567890',
  '0123456789012345',
  'Ziraat Bankasi',
  'Umraniye Subesi',
  'UZAL TEKNIK MUH. LTD. STI.',
  'TR00 0000 0000 0000 0000 0000 00',
  'TCZBTR2A',
  20,
  true
)
on conflict (id) do nothing;
