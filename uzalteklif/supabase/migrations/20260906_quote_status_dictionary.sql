-- Faz 2.1: eski depolama anahtarlarını yeni satış hunisine taşır.
alter table public.quotes drop constraint if exists quotes_status_check;
update public.quotes set status = 'approval_pending' where status = 'pending';
update public.quotes set status = 'won' where status = 'accepted';
update public.quotes set status = 'lost' where status = 'rejected';
-- Eski 'sent' kayıtları gerçek gönderim olarak korunur.

alter table public.quotes add constraint quotes_status_check check (
  status in ('draft', 'approval_pending', 'approved', 'sent', 'viewed',
             'negotiating', 'won', 'lost', 'expired', 'cancelled')
);
