-- Yonetici onay adimini kaldirir: "approved" durumuna gecis artik sadece
-- admin/manager rolune ve onceki "approval_pending" durumuna bagli degil.
-- Teklifin sahibi (ya da zaten admin/manager) kendi teklifini tamamlarken
-- dogrudan onaylanmis sayabilir. Sahiplik kontrolu fonksiyonun basindaki
-- genel "NOT_OWNER" kontrolunde zaten yapiliyor, o kural degismedi.
create or replace function public.transition_quote_status(
  p_quote_id text,
  p_target_status text,
  p_reason text default '',
  p_idempotency_key text default '',
  p_archive boolean default false
) returns setof quotes
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_quote public.quotes;
  v_role text;
  v_target text := lower(trim(p_target_status));
  v_reason text := trim(coalesce(p_reason, ''));
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select q.* into v_quote from public.quotes q where q.id = p_quote_id for update;
  if not found then raise exception 'QUOTE_NOT_FOUND'; end if;
  select role into v_role from public.user_profiles where user_id = auth.uid();
  if v_role is null then raise exception 'PROFILE_REQUIRED'; end if;

  if v_target not in ('draft','approval_pending','approved','sent','viewed','negotiating','won','lost','expired','cancelled')
    then raise exception 'INVALID_TARGET_STATUS'; end if;
  if v_quote.status = v_target and (not p_archive or v_quote.archived_at is not null)
    then return next v_quote; return; end if;
  if v_quote.owner_user_id is not null and v_quote.owner_user_id <> auth.uid()
     and v_role not in ('admin','manager') then raise exception 'NOT_OWNER'; end if;
  if v_target = 'approval_pending' and v_quote.status not in ('draft','negotiating') then raise exception 'INVALID_TRANSITION'; end if;
  -- Eskiden: sadece admin/manager, sadece 'approval_pending' halinden.
  -- Simdi: sahibi (yukarida zaten dogrulandi) taslak/pazarlik/onay-bekliyor
  -- durumundan dogrudan onaylayabilir - ayri bir yonetici onay adimi yok.
  if v_target = 'approved' and v_quote.status not in ('draft','approval_pending','negotiating') then raise exception 'INVALID_TRANSITION'; end if;
  if v_target = 'sent' and (v_quote.status not in ('approved','sent') or v_quote.email_sent_at is null) then raise exception 'EMAIL_CONFIRMATION_REQUIRED'; end if;
  if v_target = 'viewed' and (v_quote.status not in ('sent','viewed') or v_quote.email_viewed_at is null) then raise exception 'PORTAL_VIEW_REQUIRED'; end if;
  if v_target = 'won' and v_quote.accepted_at is null then raise exception 'ACCEPTANCE_REQUIRED'; end if;
  if v_target in ('lost','cancelled') and v_reason = '' then raise exception 'REASON_REQUIRED'; end if;

  perform set_config('app.status_transition', '1', true);
  update public.quotes set
    status = v_target,
    status_changed_at = timezone('utc', now()),
    approval_note = case when v_target in ('lost','cancelled') then v_reason else approval_note end,
    loss_reason_code = case when v_target = 'lost' then v_reason else loss_reason_code end,
    archived_at = case when p_archive then timezone('utc', now()) else archived_at end,
    updated_at = timezone('utc', now())
  where id = p_quote_id
  returning * into v_quote;
  return next v_quote;
end;
$function$;
