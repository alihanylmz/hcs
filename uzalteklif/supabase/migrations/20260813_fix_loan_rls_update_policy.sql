-- product_stock_loans tablosunda sadece SELECT politikası tanımlıydı;
-- UPDATE politikası eksik olduğu için Dart'ın doğrudan .update() çağrıları
-- RLS tarafından sessizce bloke ediliyordu (0 satır etkileniyor, hata yok).
-- Sonuç: zimmet kapatma / kısmi işlem hiç uygulanmıyordu.

drop policy if exists "product_stock_loans_update_staff" on public.product_stock_loans;
create policy "product_stock_loans_update_staff"
on public.product_stock_loans for update
to authenticated
using (
    exists (
        select 1 from public.profiles
        where id = auth.uid()
          and role in ('admin', 'manager', 'stock_manager')
    )
)
with check (
    exists (
        select 1 from public.profiles
        where id = auth.uid()
          and role in ('admin', 'manager', 'stock_manager')
    )
);
