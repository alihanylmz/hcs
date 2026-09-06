-- Taslak açılması gönderim kanıtı değildir. Mevcut email_sent_* alanlarına dokunulmaz.
alter table public.quotes
  add column if not exists email_draft_opened_at timestamptz,
  add column if not exists email_draft_opened_to text not null default '',
  add column if not exists email_sent_by uuid references auth.users(id) on delete set null,
  add column if not exists email_sent_by_name text not null default '',
  add column if not exists email_sent_note text not null default '';

comment on column public.quotes.email_draft_opened_at is 'E-posta taslağının istemcide açıldığı zaman; gönderim değildir.';
comment on column public.quotes.email_sent_by is 'Gönderildi olarak manuel teyit eden kullanıcı.';
