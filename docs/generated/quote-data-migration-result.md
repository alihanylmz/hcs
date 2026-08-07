# Teklif Veri Taşıma Sonucu

Kontrol zamanı: `2026-07-30 23:40 UTC`

İş akışı durumu: `success`

```text
=== quote-step-state.txt ===
checkout_ok
dart_setup_ok
key_resolution_started
key_resolution_ok

=== quote-migration-preflight.txt ===
TEKLİF VERİ TAŞIMA ENVANTERİ
Bu işlem salt okunurdur; hiçbir veri yazılmaz.

TABLO                               KAYNAK     HEDEF  DURUM
products                              2576      2576  ÇAKIŞMA KONTROLÜ GEREKLİ
customer_accounts                        4         4  ÇAKIŞMA KONTROLÜ GEREKLİ
quotes                                  53        53  ÇAKIŞMA KONTROLÜ GEREKLİ
quote_line_items                       211       432  ÇAKIŞMA KONTROLÜ GEREKLİ
quote_revisions                         53        53  ÇAKIŞMA KONTROLÜ GEREKLİ
discovery_projects                     YOK         0  KAYNAKTA YOK
discovery_device_templates             YOK         0  KAYNAKTA YOK
control_hardware_catalog               YOK         0  KAYNAKTA YOK
own_companies                            1         1  ÇAKIŞMA KONTROLÜ GEREKLİ
price_adjustment_rules                   0         0  HEDEF BOŞ
market_rates                             2         2  ÇAKIŞMA KONTROLÜ GEREKLİ
audit_logs                            4581      4581  ÇAKIŞMA KONTROLÜ GEREKLİ
user_profiles                            2         0  HEDEF BOŞ
storage: product-images                  3         3  KONTROL EDİLDİ

Kaynak Auth kullanıcı sayısı : 2
Hedef Auth kullanıcı sayısı  : 13
Kaynak toplam tablo kaydı    : 7483
Hedefte hazır Teklif tablosu : 13/13
Hedefte dolu Teklif tablosu  : 8

ENVANTER TAMAMLANDI — VERİ YAZILMADI

=== quote-schema-result.txt ===
Applying supabase/migrations/20260731_quote_legacy_bootstrap.sql
[]
Applying uzalteklif/supabase/schema.sql
[]
Applying uzalteklif/supabase/migrations/20260728_discovery_device_templates.sql
[]
Applying supabase/migrations/20260731_quote_unified_access.sql
[]

=== quote-post-schema-dry-run.txt ===
TEKLİF VERİ AKTARIM DRY-RUN
products                     kaynak=2576, hedef=2576
customer_accounts            kaynak=4, hedef=4
market_rates                 kaynak=2, hedef=2
own_companies                kaynak=1, hedef=1
price_adjustment_rules       kaynak=0, hedef=0
quotes                       kaynak=53, hedef=53
quote_line_items             kaynak=211, hedef=432
quote_revisions              kaynak=53, hedef=53
audit_logs                   kaynak=4581, hedef=4581
product-images               kaynak=3, hedef=3
DRY-RUN TAMAMLANDI — VERİ YAZILMADI

=== quote-data-migration-result.txt ===
TEKLİF VERİ AKTARIMI BAŞLIYOR
products                     kaynak=2576, hedef=2576
customer_accounts            kaynak=4, hedef=4
market_rates                 kaynak=2, hedef=2
own_companies                kaynak=1, hedef=1
price_adjustment_rules       kaynak=0, hedef=0
quotes                       kaynak=53, hedef=53
quote_line_items             kaynak=211, hedef=432
quote_revisions              kaynak=53, hedef=53
audit_logs                   kaynak=4581, hedef=4581
product-images               kaynak=3, hedef=3
Yarım kalan migration güvenli biçimde devam ettiriliyor.
products: 2576 kayıt zaten doğrulanmış, atlandı.
customer_accounts: 4 kayıt zaten doğrulanmış, atlandı.
market_rates: 2 kayıt zaten doğrulanmış, atlandı.
own_companies: 1 kayıt zaten doğrulanmış, atlandı.
price_adjustment_rules: 0 kayıt zaten doğrulanmış, atlandı.
quotes: 53 kayıt zaten doğrulanmış, atlandı.
quote_line_items: trigger kaynaklı geçici kayıtlar temizlendi.
quote_line_items: 211 kayıt aktarıldı.
quote_revisions: 53 kayıt zaten doğrulanmış, atlandı.
audit_logs: 4581 kayıt zaten doğrulanmış, atlandı.
Görsel zaten mevcut, atlandı: product-1777593434121145.jpg
Görsel zaten mevcut, atlandı: product-1777633241634222.jpg
Görsel zaten mevcut, atlandı: product-1777876815759579.jpg
TEKLİF VERİ AKTARIMI VE DOĞRULAMA TAMAMLANDI

```
