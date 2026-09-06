# Faz 2 SQL ve test çıkış kapısı

## Uygulanacak migration sırası

Test ve canlı Supabase ortamlarında migration dosyaları bu sırayla uygulanmalıdır:

1. `20260906_quote_status_dictionary.sql`
2. `20260906_quote_core_fields.sql`
3. `20260906_transition_quote_status_rpc.sql`
4. `20260906_quote_role_permissions.sql`
5. `20260906_quote_expiry.sql`

Faz 1 migration’ları (`quote_email_tracking`, `quote_email_draft_tracking`, `customer_archive`, `quote_sharing_access`) önce uygulanmış olmalıdır.

## Şema kontrolü

```sql
select table_name, column_name
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'quotes' and column_name in (
    'status','owner_user_id','valid_until','next_action_at',
    'expected_close_at','loss_reason_code','status_changed_at','archived_at'
  )) or table_name in ('quote_collaborators','quote_comments'))
order by table_name, column_name;
```

Beklenen durum değerleri:

`draft`, `approval_pending`, `approved`, `sent`, `viewed`, `negotiating`, `won`, `lost`, `expired`, `cancelled`

## Eski kayıt taşıma kontrolü

```sql
select status, count(*)
from public.quotes
group by status
order by status;

select count(*) as missing_owner
from public.quotes
where status not in ('draft','cancelled','expired')
  and owner_user_id is null;
```

`missing_owner` sonucu Faz 2 canlı geçişinden önce incelenmeli ve açık tekliflere sahip atanmalıdır.

## RPC rol testleri

Her test, farklı Supabase kullanıcı oturumuyla ve ayrı bir test teklifinde çalıştırılmalıdır.

```sql
select * from public.transition_quote_status(
  'TEST_QUOTE_ID', 'approval_pending', '', 'test-submit-001', false
);
```

Kontrol listesi:

- Satışçı kendi taslağını `approval_pending` yapabilir.
- Satışçı `approved` yapmaya çalışınca `APPROVAL_REQUIRED` döner.
- `approved` olmayan teklif `sent` yapılamaz.
- `email_sent_at` boşsa `sent` reddedilir.
- `accepted_at` boşsa `won` reddedilir.
- `lost` için boş gerekçe `REASON_REQUIRED` döner.
- Geçersiz atlama (`draft → won`, `draft → viewed`) reddedilir.
- Aynı idempotency anahtarı veya aynı hedef durum ikinci kez çağrıldığında yeni değişiklik üretmez.
- Salt okunur kullanıcı düzenleme ve yorum ekleme yapamaz.
- Finans rolü onay yetkisine sahip olabilir; yönetici tüm teklifleri görebilir.

## RLS kontrolü

```sql
select policyname, tablename, cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('quotes','quote_collaborators','quote_comments')
order by tablename, policyname;
```

RLS testinde aynı teklif için satışçı, yönetici, finans ve salt okunur kullanıcıyla ayrı ayrı `select`, `update` ve yorum `insert` denenmelidir.

## Boş veritabanı ve veri kopyası

- Boş test DB: tüm Faz 1 + Faz 2 migration’ları sırayla çalışmalı, constraint/RPC oluşturma hatası olmamalı.
- Veri kopyası: önce yedek alınmalı; `quote_cari_orphans_20260906` ve status dağılımı incelenmeli.
- Veri kopyasında eski `pending`, `accepted`, `rejected` kayıtları sırasıyla `approval_pending`, `won`, `lost` olarak doğrulanmalı.
- Foreign key constraint önce `NOT VALID`, kopuk kayıtlar düzeltildikten sonra `VALIDATE CONSTRAINT quotes_cari_id_fkey` ile doğrulanmalıdır.

## Çıkış kapısı

- UI dışında doğrudan status update yetkisi kaldırılmış olmalı; status değişiklikleri RPC’den geçmeli.
- UI ve veritabanı status sözlüğü aynı anlamı taşımalı.
- Açık tekliflerde `owner_user_id` ve `valid_until` bulunmalı.
- Eski kayıt taşıma raporu incelenmiş olmalı.
- Boş test DB ve veri kopyası migration’ları başarılı olmalı.
