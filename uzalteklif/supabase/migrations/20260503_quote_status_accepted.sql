alter table public.quotes drop constraint if exists quotes_status_check;
alter table public.quotes
add constraint quotes_status_check
check (status in ('draft', 'sent', 'pending', 'approved', 'accepted', 'rejected', 'cancelled'))
not valid;
