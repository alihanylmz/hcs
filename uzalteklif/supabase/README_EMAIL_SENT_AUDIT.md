# Şüpheli e-posta gönderim kayıtları

Faz 1.2 mevcut `email_sent_at` kayıtlarını otomatik değiştirmez. Temizleme veya düzeltme yapılmadan önce yalnızca yetkili yönetici tarafından aşağıdaki yedek alınmalıdır:

```sql
create table if not exists public.quote_email_sent_backup_20260906 as
select id, email_sent_at, email_sent_to, updated_at, now() as backed_up_at
from public.quotes
where email_sent_at is not null;
```

İnceleme için taslak açılışından kısa süre sonra işaretlenen kayıtlar raporlanabilir; ancak otomatik silme/düzeltme yapılmamalıdır. Her düzeltme için teklif id'si, eski değer, yeni değer, karar veren kullanıcı ve gerekçe ayrı bir değişiklik kaydında tutulmalıdır.
