# Uzal Teklif

Windows icin modern teklif, urun katalogu ve fiyat donusum uygulamasi.

Uygulama Flutter ile gelistirilir. Supabase bilgileri verilmezse demo/lokal veriyle calisir; Supabase bilgileri verildiginde urun ve teklif kayitlarini veritabanindan okur ve yazar.

## Ozellikler

- Urun katalogu, arama, kategori ve stok filtreleri
- Urun detay ekraninda teknik spesifikasyon, fiyat, stok ve gorsel yonetimi
- Teklif olusturma, teklif kalemleri, kategori gruplari ve gizli maliyetler
- TL, USD, EUR ve piyasa kuru snapshot destegi
- Nakit, kart ve vadeli odeme secimleri
- Taslak, onaya gonderildi, onaylandi, revizyon ve reddedildi durum akisi
- PDF teklif ciktisi, QR/kisa link ve onayli tekliflerde kase destegi
- Excel teklif ciktisi
- Supabase schema dosyasi ve lokal/demo fallback

## Gereksinimler

- Flutter beta kanali, Dart `3.11.0-200.1.beta` veya uyumlu surum
- Windows desktop destegi
- Supabase kullanilacaksa Supabase projesinde anonymous sign-in aktif olmali

Mevcut gelistirme ortami:

```powershell
flutter --version
```

## Kurulum

```powershell
flutter pub get
flutter test
flutter analyze
```

Uygulamayi Windows'ta calistirmak icin:

```powershell
flutter run -d windows
```

Release build almak icin:

```powershell
flutter build windows
```

## Supabase

Veritabani semasi [supabase/schema.sql](supabase/schema.sql) dosyasindadir. Demo veriler icin [supabase/seed.sql](supabase/seed.sql), gelistirme reset'i icin [supabase/reset.sql](supabase/reset.sql) kullanilir.

Supabase ile calistirmak icin uygulamayi su dart-define degerleriyle baslatin:

```powershell
flutter run -d windows `
  --dart-define=SUPABASE_URL=https://PROJECT_ID.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  --dart-define=PUBLIC_QUOTE_BASE_URL=https://uzalteknik.com/t `
  --dart-define=UPDATE_GITHUB_REPO=OWNER/REPO
```

Alternatif olarak lokal ayar dosyasini kullanabilirsiniz:

```powershell
flutter run -d windows --dart-define-from-file=config/supabase.local.json
```

VS Code icinde **Uzal Teklif (Windows + Supabase)** launch profili ayni lokal ayar dosyasini kullanir. Gercek degerleri `config/supabase.local.json` icine yazin; bu dosya git'e eklenmez. Paylasilabilir sablon `config/supabase.example.json` dosyasidir.

Notlar:

- `SUPABASE_URL` ve `SUPABASE_ANON_KEY` bos ise uygulama demo/lokal veri kullanir.
- Schema RLS politikalari `authenticated` role icin yazildigindan uygulama baslangicta anonim oturum acmayi dener.
- Supabase projesinde anonymous sign-in kapaliysa uygulama veritabanina baglanmak yerine demo/lokal veriyle devam eder.
- `PUBLIC_QUOTE_BASE_URL`, PDF uzerindeki QR ve kisa linklerin kok adresidir.
- `UPDATE_GITHUB_REPO`, Windows uygulamasinin GitHub Releases uzerinden yeni surum kontrol edecegi `OWNER/REPO` adresidir.

## Windows Release ve Guncelleme

Tag push edildiginde `.github/workflows/release-windows.yml` Windows paketini olusturur ve GitHub Release'e `uzalteklif-windows-x64.zip` olarak yukler:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

GitHub repo ayarlarinda su degerleri tanimlayin:

- Secrets: `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- Variables: `PUBLIC_QUOTE_BASE_URL`, opsiyonel `UPDATE_GITHUB_REPO`

`UPDATE_GITHUB_REPO` verilmezse release build otomatik olarak mevcut GitHub reposunu kullanir. Uygulama acilista daha yeni bir GitHub Release bulursa kullaniciya indirme penceresi gosterir.

### Supabase Panel Ayarlari

1. Supabase Dashboard > SQL Editor ekraninda [supabase/schema.sql](supabase/schema.sql) dosyasini calistirin.
2. Kur tablosunu hemen doldurmak icin [supabase/market_rates_fill.sql](supabase/market_rates_fill.sql) dosyasini calistirin.
3. Demo urun ve teklif kaydi isterseniz [supabase/seed.sql](supabase/seed.sql) dosyasini calistirin.
4. Authentication > Providers ekraninda Anonymous sign-ins ayarini aktif edin.
5. Project Settings > API ekranindan Project URL degerini `SUPABASE_URL`, anon public key degerini `SUPABASE_ANON_KEY` olarak girin.
6. Table Editor ekraninda `products`, `quotes` ve `market_rates` tablolarinin olustugunu kontrol edin.
7. Gelistirme ortaminda sifirdan kurmak gerekirse once [supabase/reset.sql](supabase/reset.sql), sonra tekrar schema ve seed SQL'lerini calistirin.

### Canli Kur Akisi

Uygulama Supabase bagliyken kurlari once `market_rates` tablosundan okur. Bu tablo [supabase/functions/refresh-market-rates/index.ts](supabase/functions/refresh-market-rates/index.ts) Edge Function'i ile guncellenir.

Kurulum sirasi:

```powershell
supabase functions deploy refresh-market-rates
supabase functions invoke refresh-market-rates
```

Supabase Dashboard > Edge Functions ekraninda fonksiyonu schedule/cron ile 10 dakikada bir calistirabilirsiniz. Fonksiyon USD/TRY ve EUR/TRY icin TCMB `today.xml` doviz satis kurunu kullanir. TCMB verisi alinamazsa `open.er-api.com` yedek kaynak olarak denenir, sonra `market_rates` tablosuna yazar.

## Testler

```powershell
flutter test
flutter analyze
```

Mevcut test kapsami:

- Ana ekran teklif akisi render testi
- Teklif editorunde kod plakasi ve katalogdan kalem ekleme testi
- Teklif kodu formati testi
- PDF servisinin bos olmayan dokuman uretme testi

PDF tasarim onizlemesi test sirasinda `output/pdf/preview_quote.pdf` konumuna yazilir.

## Proje Yapisi

```text
lib/
  app/        Uygulama bootstrap ve servis kurulumu
  config/     Firma profili, uygulama ayarlari ve urun spesifikasyon sablonlari
  models/     Product, Quote ve MarketRate modelleri
  screens/    Ana ekran, urun detay, teklif listesi, teklif editoru ve onay ekranlari
  services/   Repository, PDF, Excel, kur, gorsel ve kase servisleri
  theme/      Uygulama temasi
  widgets/    Ortak UI parcalari
supabase/
  schema.sql  Products ve quotes tablolari, indeksler ve RLS politikalari
test/         Widget ve servis testleri
```

## Uretime Hazirlama Kontrol Listesi

- Supabase projesinde `supabase/schema.sql` calistirildi
- Anonymous sign-in veya hedeflenen auth yontemi aktif edildi
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PUBLIC_QUOTE_BASE_URL` ve `UPDATE_GITHUB_REPO` build/run komutlarina eklendi
- Firma profili [lib/config/company_profile.dart](lib/config/company_profile.dart) icinde kontrol edildi
- PDF ornek ciktisi gozel kontrol edildi
- `flutter test` ve `flutter analyze` temiz gecti
