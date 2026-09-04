-- Sales ekiplerinin ayni teklif havuzunu gorebilmesi ve paylasilan
-- tekliflerin olusturan disindaki kullanicilarca da guncellenebilmesi icin
-- quote access kurallari genisletilir.

create or replace function public.can_view_quote_record(
  p_created_by uuid,
  p_shared_with text[] default '{}'
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.can_access_quote_app()
    and (
      public.is_quote_manager()
      or p_created_by = auth.uid()
      or exists (
        select 1
        from public.user_app_access access
        where access.user_id = auth.uid()
          and access.app_code = 'teklif'
          and access.is_active
          and access.app_role in (
            'admin',
            'manager',
            'sales',
            'finance',
            'operations'
          )
      )
      or coalesce(auth.jwt() ->> 'email', '') = any (coalesce(p_shared_with, '{}'))
      or auth.uid()::text = any (coalesce(p_shared_with, '{}'))
    );
$$;

create or replace function public.can_update_quote_record(
  p_created_by uuid,
  p_shared_with text[] default '{}'
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.can_edit_quote_app()
    and (
      public.is_quote_manager()
      or p_created_by is null
      or p_created_by = auth.uid()
      or coalesce(auth.jwt() ->> 'email', '') = any (coalesce(p_shared_with, '{}'))
      or auth.uid()::text = any (coalesce(p_shared_with, '{}'))
    );
$$;

grant execute on function public.can_view_quote_record(uuid, text[]) to authenticated;
grant execute on function public.can_update_quote_record(uuid, text[]) to authenticated;

drop policy if exists "quotes_select_scope" on public.quotes;
drop policy if exists "quotes_update_scope" on public.quotes;

create policy "quotes_select_scope"
on public.quotes
for select to authenticated
using (
  public.can_view_quote_record(created_by, shared_with)
);

create policy "quotes_update_scope"
on public.quotes
for update to authenticated
using (
  public.can_update_quote_record(created_by, shared_with)
)
with check (
  public.can_update_quote_record(created_by, shared_with)
);
