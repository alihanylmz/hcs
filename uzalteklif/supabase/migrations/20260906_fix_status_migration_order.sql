-- Durum migration'ı yarıda kaldıysa güvenli yeniden çalıştırma düzeltmesi.
begin;

alter table public.quotes drop constraint if exists quotes_status_check;
select set_config('app.status_transition', '1', true);

update public.quotes set status = 'approval_pending' where status in ('pending', 'approval_pending');
update public.quotes set status = 'won' where status in ('accepted', 'won');
update public.quotes set status = 'lost' where status in ('rejected', 'lost');
update public.quotes set status = 'draft' where status is null or trim(status) = '';

alter table public.quotes add constraint quotes_status_check check (
  status in ('draft', 'approval_pending', 'approved', 'sent', 'viewed',
             'negotiating', 'won', 'lost', 'expired', 'cancelled')
);

commit;
