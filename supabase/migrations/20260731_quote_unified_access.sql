-- Teklif şeması ortak İş Takip Supabase projesine kurulduktan sonra çalışır.
-- Eski `user_profiles` yetki modelini kullanmaz; `profiles` ve
-- `user_app_access` ortak kullanıcı omurgasıdır.

begin;

create table if not exists public.quote_data_migration_runs (
  migration_id text primary key,
  status text not null,
  source_counts jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  error_message text not null default '',
  constraint quote_data_migration_runs_status_check
    check (status in ('running', 'failed', 'completed'))
);

alter table public.quote_data_migration_runs enable row level security;
revoke all on public.quote_data_migration_runs from anon, authenticated;

create or replace function public.can_access_quote_app()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_app_access access
    where access.user_id = auth.uid()
      and access.app_code = 'teklif'
      and access.is_active
  );
$$;

create or replace function public.can_edit_quote_app()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
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
  );
$$;

create or replace function public.is_quote_manager()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_app_access access
    where access.user_id = auth.uid()
      and access.app_code = 'teklif'
      and access.is_active
      and access.app_role in ('admin', 'manager')
  );
$$;

create or replace function public.is_system_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role::text = 'admin'
  );
$$;

create or replace function public.user_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(profile.full_name, ''),
    nullif(profile.email, ''),
    'Kullanıcı'
  )
  from public.profiles profile
  where profile.id = p_user_id;
$$;

grant execute on function public.can_access_quote_app() to authenticated;
grant execute on function public.can_edit_quote_app() to authenticated;
grant execute on function public.is_quote_manager() to authenticated;
grant execute on function public.is_system_admin() to authenticated;
grant execute on function public.user_display_name(uuid) to authenticated;

-- Ortak Supabase'teki İş Takip kullanıcıları, Teklif yetkisi olmadan satış
-- verilerini göremez. `service_role` veri taşımasında RLS'yi güvenle aşar.
revoke all on
  public.products,
  public.quotes,
  public.market_rates,
  public.customer_accounts,
  public.price_adjustment_rules,
  public.audit_logs,
  public.quote_revisions,
  public.quote_line_items,
  public.discovery_projects,
  public.discovery_device_templates,
  public.control_hardware_catalog,
  public.own_companies
from anon;

grant select, insert, update, delete on
  public.products,
  public.quotes,
  public.customer_accounts,
  public.price_adjustment_rules,
  public.discovery_projects,
  public.discovery_device_templates,
  public.control_hardware_catalog,
  public.own_companies
to authenticated;

grant select on
  public.audit_logs,
  public.quote_revisions,
  public.quote_line_items
to authenticated;

grant select on public.market_rates to anon, authenticated;
grant insert, update, delete on public.market_rates to authenticated;

drop policy if exists "Allow authenticated users to read products"
on public.products;
drop policy if exists "Allow authenticated users to write products"
on public.products;
create policy "Allow authenticated users to read products"
on public.products
for select to authenticated
using (public.can_access_quote_app());
create policy "Allow authenticated users to write products"
on public.products
for all to authenticated
using (public.can_edit_quote_app())
with check (public.can_edit_quote_app());

drop policy if exists "quotes_select_scope" on public.quotes;
drop policy if exists "quotes_insert_authenticated" on public.quotes;
drop policy if exists "quotes_update_scope" on public.quotes;
drop policy if exists "quotes_delete_scope" on public.quotes;
create policy "quotes_select_scope"
on public.quotes
for select to authenticated
using (public.can_access_quote_app());
create policy "quotes_insert_authenticated"
on public.quotes
for insert to authenticated
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid())
);
create policy "quotes_update_scope"
on public.quotes
for update to authenticated
using (public.can_edit_quote_app())
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid() or public.is_quote_manager())
);
create policy "quotes_delete_scope"
on public.quotes
for delete to authenticated
using (
  public.is_quote_manager()
  or (public.can_edit_quote_app() and created_by = auth.uid())
);

drop policy if exists "customer_accounts_select_company"
on public.customer_accounts;
drop policy if exists "customer_accounts_insert_authenticated"
on public.customer_accounts;
drop policy if exists "customer_accounts_update_company"
on public.customer_accounts;
drop policy if exists "customer_accounts_delete_scope"
on public.customer_accounts;
create policy "customer_accounts_select_company"
on public.customer_accounts
for select to authenticated
using (public.can_access_quote_app());
create policy "customer_accounts_insert_authenticated"
on public.customer_accounts
for insert to authenticated
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid())
);
create policy "customer_accounts_update_company"
on public.customer_accounts
for update to authenticated
using (public.can_edit_quote_app())
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid() or public.is_quote_manager())
);
create policy "customer_accounts_delete_scope"
on public.customer_accounts
for delete to authenticated
using (
  public.is_quote_manager()
  or (public.can_edit_quote_app() and created_by = auth.uid())
);

drop policy if exists "Authenticated read price adjustment rules"
on public.price_adjustment_rules;
drop policy if exists "Managers manage price adjustment rules"
on public.price_adjustment_rules;
create policy "Authenticated read price adjustment rules"
on public.price_adjustment_rules
for select to authenticated
using (public.can_access_quote_app());
create policy "Managers manage price adjustment rules"
on public.price_adjustment_rules
for all to authenticated
using (public.is_quote_manager())
with check (public.is_quote_manager());

drop policy if exists "Managers read audit logs" on public.audit_logs;
create policy "Managers read audit logs"
on public.audit_logs
for select to authenticated
using (public.is_quote_manager());

drop policy if exists "Managers read quote revisions"
on public.quote_revisions;
create policy "Managers read quote revisions"
on public.quote_revisions
for select to authenticated
using (public.is_quote_manager());

drop policy if exists "quote_line_items_select_scope"
on public.quote_line_items;
create policy "quote_line_items_select_scope"
on public.quote_line_items
for select to authenticated
using (public.can_access_quote_app());

drop policy if exists "discovery_projects_select_scope"
on public.discovery_projects;
drop policy if exists "discovery_projects_insert_authenticated"
on public.discovery_projects;
drop policy if exists "discovery_projects_update_scope"
on public.discovery_projects;
drop policy if exists "discovery_projects_delete_scope"
on public.discovery_projects;
create policy "discovery_projects_select_scope"
on public.discovery_projects
for select to authenticated
using (public.can_access_quote_app());
create policy "discovery_projects_insert_authenticated"
on public.discovery_projects
for insert to authenticated
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid())
);
create policy "discovery_projects_update_scope"
on public.discovery_projects
for update to authenticated
using (public.can_edit_quote_app())
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid() or public.is_quote_manager())
);
create policy "discovery_projects_delete_scope"
on public.discovery_projects
for delete to authenticated
using (
  public.is_quote_manager()
  or (public.can_edit_quote_app() and created_by = auth.uid())
);

drop policy if exists "Authenticated users can read discovery device templates"
on public.discovery_device_templates;
drop policy if exists "Authenticated users can create discovery device templates"
on public.discovery_device_templates;
drop policy if exists "Creators can update discovery device templates"
on public.discovery_device_templates;
drop policy if exists "Creators can delete discovery device templates"
on public.discovery_device_templates;
create policy "Authenticated users can read discovery device templates"
on public.discovery_device_templates
for select to authenticated
using (public.can_access_quote_app());
create policy "Authenticated users can create discovery device templates"
on public.discovery_device_templates
for insert to authenticated
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid())
);
create policy "Creators can update discovery device templates"
on public.discovery_device_templates
for update to authenticated
using (public.can_edit_quote_app())
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid() or public.is_quote_manager())
);
create policy "Creators can delete discovery device templates"
on public.discovery_device_templates
for delete to authenticated
using (
  public.is_quote_manager()
  or (public.can_edit_quote_app() and created_by = auth.uid())
);

drop policy if exists "control_hardware_select_authenticated"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_insert_authenticated"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_update_scope"
on public.control_hardware_catalog;
drop policy if exists "control_hardware_delete_scope"
on public.control_hardware_catalog;
create policy "control_hardware_select_authenticated"
on public.control_hardware_catalog
for select to authenticated
using (public.can_access_quote_app());
create policy "control_hardware_insert_authenticated"
on public.control_hardware_catalog
for insert to authenticated
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid())
);
create policy "control_hardware_update_scope"
on public.control_hardware_catalog
for update to authenticated
using (public.can_edit_quote_app())
with check (
  public.can_edit_quote_app()
  and (created_by is null or created_by = auth.uid() or public.is_quote_manager())
);
create policy "control_hardware_delete_scope"
on public.control_hardware_catalog
for delete to authenticated
using (
  public.is_quote_manager()
  or (public.can_edit_quote_app() and created_by = auth.uid())
);

drop policy if exists "Authenticated users read own companies"
on public.own_companies;
drop policy if exists "Managers manage own companies"
on public.own_companies;
create policy "Authenticated users read own companies"
on public.own_companies
for select to authenticated
using (public.can_access_quote_app());
create policy "Managers manage own companies"
on public.own_companies
for all to authenticated
using (public.is_quote_manager())
with check (public.is_quote_manager());

drop policy if exists "Allow public users to read market rates"
on public.market_rates;
create policy "Allow public users to read market rates"
on public.market_rates
for select to anon, authenticated
using (true);

drop policy if exists "product_images_public_read" on storage.objects;
drop policy if exists "product_images_auth_insert" on storage.objects;
drop policy if exists "product_images_auth_update" on storage.objects;
drop policy if exists "product_images_auth_delete" on storage.objects;
create policy "product_images_public_read"
on storage.objects
for select
using (bucket_id = 'product-images');
create policy "product_images_auth_insert"
on storage.objects
for insert to authenticated
with check (
  bucket_id = 'product-images'
  and public.can_edit_quote_app()
);
create policy "product_images_auth_update"
on storage.objects
for update to authenticated
using (
  bucket_id = 'product-images'
  and public.can_edit_quote_app()
)
with check (
  bucket_id = 'product-images'
  and public.can_edit_quote_app()
);
create policy "product_images_auth_delete"
on storage.objects
for delete to authenticated
using (
  bucket_id = 'product-images'
  and public.can_edit_quote_app()
);

notify pgrst, 'reload schema';

commit;
