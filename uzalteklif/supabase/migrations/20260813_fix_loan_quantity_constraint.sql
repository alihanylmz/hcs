-- Zimmet kaydı kapatılırken quantity=0 yazılmasına izin vermek için
-- check (quantity > 0) kısıtını check (quantity >= 0) olarak genişlet.
-- Aktif zimmetler getOpenPersonnelLoans() sorgusunda .gt('quantity', 0) ile
-- zaten filtreleniyor; bu değişiklik mevcut aktif kayıtları etkilemez.

alter table public.product_stock_loans
  drop constraint if exists product_stock_loans_quantity_check;

alter table public.product_stock_loans
  add constraint product_stock_loans_quantity_check check (quantity >= 0);
