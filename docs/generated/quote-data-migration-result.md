# Teklif Veri Taşıma Sonucu

Kontrol zamanı: `2026-07-30 23:31 UTC`

İş akışı durumu: `failure`

```text
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
Applying uzalteklif/supabase/schema.sql
curl: (22) The requested URL returned error: 400
{"message":"Failed to run sql query: ERROR:  42P01: relation \"public.user_profiles\" does not exist\nLINE 391:     nullif((select up.prepared_by_name from public.user_profiles up where up.user_id = p_user_id), ''),\n                                                      ^\n"}
```
