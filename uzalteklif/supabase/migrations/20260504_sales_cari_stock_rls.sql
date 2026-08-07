-- Cari kartlari firma ortak havuzudur: tum oturumlu kullanicilar okuyabilir.
-- Satis kullanicilari stok karti ekleyip duzenleyebilir; fiyat politikasi gibi
-- toplu ve riskli islemler ayrica manager/admin yetkisinde kalir.

drop policy if exists "Authenticated manage customer accounts" on public.customer_accounts;
drop policy if exists "customer_accounts_select_company" on public.customer_accounts;
drop policy if exists "customer_accounts_insert_authenticated" on public.customer_accounts;
drop policy if exists "customer_accounts_update_company" on public.customer_accounts;
drop policy if exists "customer_accounts_delete_scope" on public.customer_accounts;

create policy "customer_accounts_select_company"
on public.customer_accounts
for select
to authenticated
using (true);

create policy "customer_accounts_insert_authenticated"
on public.customer_accounts
for insert
to authenticated
with check (
  created_by is null
  or created_by = auth.uid()
);

create policy "customer_accounts_update_company"
on public.customer_accounts
for update
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
)
with check (
  public.is_quote_manager()
  or created_by is null
  or created_by = auth.uid()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
);

create policy "customer_accounts_delete_scope"
on public.customer_accounts
for delete
to authenticated
using (
  public.is_quote_manager()
  or created_by = auth.uid()
);

drop policy if exists "Allow authenticated users to write products" on public.products;
create policy "Allow authenticated users to write products"
on public.products
for all
to authenticated
using (
  public.is_quote_manager()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
)
with check (
  public.is_quote_manager()
  or exists (
    select 1 from public.user_profiles u
    where u.user_id = auth.uid()
      and u.role in (
        'sales',
        'seller',
        'sales_engineer',
        'mechatronics_engineer',
        'electrical_electronics_engineer',
        'operations',
        'finance'
      )
  )
);
