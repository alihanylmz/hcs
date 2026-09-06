# Faz 1 — Supabase SQL uygulama listesi

Faz 2’ye geçmeden önce test Supabase projesinde, ardından canlıda aşağıdaki migration’lar sırayla çalıştırılmalıdır. Eski migration dosyaları yeniden çalıştırılmamalı; yalnız eksik olanlar uygulanmalıdır.

## Faz 1 için zorunlu migration’lar

1. `uzalteklif/supabase/migrations/20260813_quote_email_tracking.sql`
   - `email_viewed_at` alanını ekler.
2. `uzalteklif/supabase/migrations/20260814_quote_sharing_access.sql`
   - `shared_with` ve ilgili erişim politikalarını ekler.
3. `uzalteklif/supabase/migrations/20260906_quote_email_draft_tracking.sql`
   - Taslak açılışı ile gerçek/manuel gönderimi ayırır.
   - `email_draft_opened_at`, `email_draft_opened_to`, `email_sent_by`, `email_sent_by_name`, `email_sent_note` alanlarını ekler.
4. `uzalteklif/supabase/migrations/20260906_customer_archive.sql`
   - Cari arşivleme için `archived_at` ve `is_active` alanlarını ekler.

## Uygulama öncesi yedek

Canlıda mevcut gönderim kayıtlarını değiştirmeden önce:

```sql
create table if not exists public.quote_email_sent_backup_20260906 as
select id, email_sent_at, email_sent_to, updated_at, now() as backed_up_at
from public.quotes
where email_sent_at is not null;
```

Arşiv migration’ı mevcut carileri otomatik silmez. `is_active` varsayılanı `true` olduğu için eski cariler aktif kalır.

## Kontrol sorguları

```sql
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('quotes', 'customer_accounts')
  and column_name in (
    'email_viewed_at', 'email_draft_opened_at', 'email_draft_opened_to',
    'email_sent_by', 'email_sent_by_name', 'email_sent_note',
    'archived_at', 'is_active'
  )
order by table_name, column_name;
```

Beklenen sonuç: `quotes` için 6, `customer_accounts` için 2 alan.

## Faz 1 güvenlik doğrulaması

```sql
-- Arşivlenmiş cariler yeni seçimlerde görünmemeli
select count(*) as archived_active_error
from public.customer_accounts
where archived_at is not null and is_active = true;

-- Teklifler cariye bağlı kalmalı
select q.id, q.cari_id
from public.quotes q
join public.customer_accounts c on c.id = q.cari_id
where c.archived_at is not null;
```

İlk sorgunun sonucu `0` olmalıdır. İkinci sorgu kayıt döndürebilir; bu, arşivlenen carinin eski tekliflerinin korunduğunu gösterir.

Canlıya uygulama öncesinde aynı migration’lar test ortamında çalıştırılmalı ve uygulamanın 15’li teklif/cari/PDF test paketi başarıyla tamamlanmalıdır.
