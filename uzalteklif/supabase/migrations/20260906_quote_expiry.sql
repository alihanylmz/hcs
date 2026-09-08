-- Geçerlilik tarihi geçen açık teklifleri kontrollü olarak expired yapar.
create or replace function public.expire_open_quotes()
returns integer
language plpgsql security definer set search_path = public as $$
declare v_count integer;
begin
  if not exists (select 1 from public.user_profiles where user_id = auth.uid() and role in ('admin','manager')) then
    raise exception 'MANAGER_REQUIRED';
  end if;
  update public.quotes
  set status = 'expired', status_changed_at = timezone('utc', now()), updated_at = timezone('utc', now())
  where valid_until < current_date
    and status in ('draft','approval_pending','approved','sent','viewed','negotiating');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.expire_open_quotes() from public;
grant execute on function public.expire_open_quotes() to authenticated;
