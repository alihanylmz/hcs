-- Teklif e-posta gonderim ve musteri cevap takibi.
-- Musteri public linki gordugunde email_viewed_at guncellenir (public quote
-- endpoint uzerinden). Dart tarafinda markEmailSent() ile email_sent_at
-- ve email_sent_to guncellenir.

alter table public.quotes
  add column if not exists email_sent_at   timestamptz,
  add column if not exists email_sent_to   text not null default '',
  add column if not exists email_viewed_at timestamptz,
  add column if not exists customer_response text not null default 'pending'
    constraint quotes_customer_response_check
      check (customer_response in ('pending', 'accepted', 'rejected', 'no_response'));

comment on column public.quotes.email_sent_at    is 'Teklifin musteri e-postasina gonderildigi tarih (UTC).';
comment on column public.quotes.email_sent_to    is 'Teklifin gonderildigi e-posta adresi.';
comment on column public.quotes.email_viewed_at  is 'Musterinin public teklif linkini ilk actigi tarih (UTC).';
comment on column public.quotes.customer_response is 'Musterinin teklif karari: pending | accepted | rejected | no_response.';
