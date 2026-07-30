-- Eski Teklif şemasındaki `user_display_name` fonksiyonu bu tabloyu,
-- şema dosyasında tablo tanımından önce kullanıyor. Temiz hedef kurulumunda
-- yalnızca bağımlılık sırasını düzeltmek için tablo önceden oluşturulur.
-- Ortak kullanıcı yetkileri bu tabloyu kullanmaz.

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  prepared_by_name text not null default '',
  prepared_by_title text not null default '',
  prepared_by_phone text not null default '',
  prepared_by_email text not null default '',
  company_name text not null default '',
  company_tagline text not null default '',
  company_phone text not null default '',
  company_email text not null default '',
  company_website text not null default '',
  company_address text not null default '',
  company_tax_office text not null default '',
  company_tax_number text not null default '',
  company_mersis text not null default '',
  bank_name text not null default '',
  bank_branch text not null default '',
  bank_account_name text not null default '',
  bank_iban text not null default '',
  bank_swift text not null default '',
  default_validity_text text not null default '',
  default_payment_terms text not null default '',
  default_delivery_terms text not null default '',
  default_vat_rate numeric(5,2) not null default 20,
  updated_at timestamptz not null default timezone('utc', now())
);
