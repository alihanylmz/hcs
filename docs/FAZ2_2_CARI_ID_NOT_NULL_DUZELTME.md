# Faz 2.2 cari_id düzeltmesi

Migration `cari_id` alanını `NULL` yapmak isterken eski `NOT NULL` kısıtı nedeniyle durduysa SQL Editor’da şu düzeltmeyi çalıştırın:

```sql
begin;

alter table public.quotes alter column cari_id drop not null;

update public.quotes
set cari_id = null
where cari_id is null or trim(cari_id) = '';

alter table public.quotes drop constraint if exists quotes_cari_id_fkey;
alter table public.quotes
  add constraint quotes_cari_id_fkey
  foreign key (cari_id)
  references public.customer_accounts(id)
  on delete set null
  not valid;

commit;
```

Kopuk ilişkileri görmek için:

```sql
select q.id, q.cari_id
from public.quotes q
left join public.customer_accounts c on c.id = q.cari_id
where q.cari_id is not null and c.id is null;
```

Bu kayıtlar düzeltilmeden `validate constraint quotes_cari_id_fkey` çalıştırılmamalıdır.
