alter table public.inventory
add column if not exists barcode text;

create unique index if not exists inventory_barcode_unique_idx
on public.inventory (barcode)
where barcode is not null and barcode <> '';
