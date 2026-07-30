# Teklif Veri Taşıma Sonucu

Kontrol zamanı: `2026-07-30 23:37 UTC`

İş akışı durumu: `failure`

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
products                              2576       YOK  HEDEF ŞEMA GEREKLİ
customer_accounts                        4       YOK  HEDEF ŞEMA GEREKLİ
quotes                                  53       YOK  HEDEF ŞEMA GEREKLİ
quote_line_items                       211       YOK  HEDEF ŞEMA GEREKLİ
quote_revisions                         53       YOK  HEDEF ŞEMA GEREKLİ
discovery_projects                     YOK       YOK  KAYNAKTA YOK
discovery_device_templates             YOK       YOK  KAYNAKTA YOK
control_hardware_catalog               YOK       YOK  KAYNAKTA YOK
own_companies                            1       YOK  HEDEF ŞEMA GEREKLİ
price_adjustment_rules                   0       YOK  HEDEF ŞEMA GEREKLİ
market_rates                             2       YOK  HEDEF ŞEMA GEREKLİ
audit_logs                            4581       YOK  HEDEF ŞEMA GEREKLİ
user_profiles                            2       YOK  HEDEF ŞEMA GEREKLİ
storage: product-images                  3         0  KONTROL EDİLDİ

Kaynak Auth kullanıcı sayısı : 2
Hedef Auth kullanıcı sayısı  : 13
Kaynak toplam tablo kaydı    : 7483
Hedefte hazır Teklif tablosu : 0/13
Hedefte dolu Teklif tablosu  : 0

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
products                     kaynak=2576, hedef=0
customer_accounts            kaynak=4, hedef=0
market_rates                 kaynak=2, hedef=0
own_companies                kaynak=1, hedef=0
price_adjustment_rules       kaynak=0, hedef=0
quotes                       kaynak=53, hedef=0
quote_line_items             kaynak=211, hedef=0
quote_revisions              kaynak=53, hedef=0
audit_logs                   kaynak=4581, hedef=0
product-images               kaynak=3, hedef=0
DRY-RUN TAMAMLANDI — VERİ YAZILMADI

=== quote-data-migration-result.txt ===
TEKLİF VERİ AKTARIMI BAŞLIYOR
products                     kaynak=2576, hedef=0
customer_accounts            kaynak=4, hedef=0
market_rates                 kaynak=2, hedef=0
own_companies                kaynak=1, hedef=0
price_adjustment_rules       kaynak=0, hedef=0
quotes                       kaynak=53, hedef=0
quote_line_items             kaynak=211, hedef=0
quote_revisions              kaynak=53, hedef=0
audit_logs                   kaynak=4581, hedef=0
product-images               kaynak=3, hedef=0
products: 2576 kayıt aktarıldı.
customer_accounts: 4 kayıt aktarıldı.
market_rates: 2 kayıt aktarıldı.
own_companies: 1 kayıt aktarıldı.
price_adjustment_rules: 0 kayıt aktarıldı.
quotes: 53 kayıt aktarıldı.
quote_line_items: 211 kayıt aktarıldı.
quote_revisions: 53 kayıt aktarıldı.
audit_logs: 4581 kayıt aktarıldı.
Görsel aktarıldı: product-1777593434121145.jpg
Görsel aktarıldı: product-1777633241634222.jpg
Görsel aktarıldı: product-1777876815759579.jpg

```
