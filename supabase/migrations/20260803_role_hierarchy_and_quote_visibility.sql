-- Uzal Teknik kurumsal yetki hiyerarşisi.
-- profiles.role = admin yalnızca Genel Müdürdür.
-- profiles.role = manager Patron operasyon yetkisidir.

begin;

create or replace function public.is_unified_user_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.role::text = 'admin'
      from public.profiles p
      where p.id = auth.uid()
    ),
    false
  );
$$;

grant execute on function public.is_unified_user_manager() to authenticated;

drop policy if exists user_app_access_select_scope
on public.user_app_access;
create policy user_app_access_select_scope
on public.user_app_access
for select to authenticated
using (
  user_id = auth.uid()
  or public.is_unified_user_manager()
);

drop policy if exists user_app_access_manage_scope
on public.user_app_access;
create policy user_app_access_manage_scope
on public.user_app_access
for all to authenticated
using (public.is_unified_user_manager())
with check (public.is_unified_user_manager());

create or replace function public.can_view_quote(p_creator_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  with current_access as (
    select access.app_role
    from public.user_app_access access
    where access.user_id = auth.uid()
      and access.app_code = 'teklif'
      and access.is_active
  )
  select coalesce(
    exists (select 1 from current_access)
    and (
      -- Genel Müdür, Patron, Finans, Operasyon ve salt-okunur kullanıcılar
      -- normal uygulama kapsamlarının tamamını görür.
      not exists (
        select 1 from current_access where app_role = 'sales'
      )
      -- Satış personeli kendi teklifi dahil olmak üzere Patron dışındaki
      -- kullanıcıların tekliflerini görür.
      or p_creator_id is null
      or p_creator_id = auth.uid()
      or not exists (
        select 1
        from public.user_app_access creator_access
        where creator_access.user_id = p_creator_id
          and creator_access.app_code = 'teklif'
          and creator_access.is_active
          and creator_access.app_role = 'manager'
      )
    ),
    false
  );
$$;

revoke all on function public.can_view_quote(uuid) from public;
grant execute on function public.can_view_quote(uuid) to authenticated;

drop policy if exists "quotes_select_scope" on public.quotes;
create policy "quotes_select_scope"
on public.quotes
for select to authenticated
using (public.can_view_quote(created_by));

drop policy if exists "quote_line_items_select_scope"
on public.quote_line_items;
create policy "quote_line_items_select_scope"
on public.quote_line_items
for select to authenticated
using (
  exists (
    select 1
    from public.quotes quote
    where quote.id = quote_line_items.quote_id
      and public.can_view_quote(quote.created_by)
  )
);

comment on function public.can_view_quote(uuid) is
  'Satış personelinden Patronların hazırladığı teklifleri veritabanı seviyesinde gizler.';

commit;
