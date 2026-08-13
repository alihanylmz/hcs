# Antigravity Project Instructions

Bu dosya, bu repoda calisan tum yapay zeka ajanlari icin baglayici proje talimatidir. Her goreve baslamadan once bu dosyanin tamamini oku ve gorev boyunca uygula. Alt klasorlerde daha ozel bir `AGENTS.md` varsa, o dosya yalnizca kendi klasoru icin bu kurallari tamamlar veya daha ozel hale getirir.

## Calisma Bicimi

- Antigravity ve diger AI ajanlari, projeye her erisimde once `.agents/AGENTS.md` dosyasinin tamamini otomatik olarak okumus kabul edilir ve buradaki kod yazim, mimari, test, yayin ve guvenlik standartlarina harfiyen uyar.
- Once istegi, ilgili kodu ve mevcut mimariyi incele; yeterli baglam edinmeden degisiklik yapma.
- Kullanici yalnizca aciklama, inceleme veya teshis istediyse kodu degistirme.
- Kullanici degisiklik istediyse isi analiz, uygulama ve dogrulama adimlariyla tamamla; yarim birakma.
- Belirsiz ama dusuk riskli ayrintilarda mevcut proje kaliplarini izleyerek makul karar ver. Sonucu veya veri modelini ciddi bicimde degistirecek belirsizliklerde kullaniciya sor.
- Degisiklikleri istenen kapsamda tut. Ilgisiz refactor, dosya tasima, yeniden adlandirma, bagimlilik guncelleme veya bicimlendirme yapma.
- Kullaniciya ait mevcut ve commit edilmemis degisiklikleri koru. Senin olusturmadigin degisiklikleri geri alma.
- Gizli anahtar, parola, token, servis anahtari veya gercek ortam verisini koda, loga ya da dokumantasyona yazma.
- Acikca istenmedikce commit, push, release, migration calistirma veya uzak sistemlerde veri degistirme.

## Kullaniciya Ozel Kurallar

- `.info` uzantili ortam test/staging alani olarak kabul edilir. Testler, denemeler, on izleme yayinlari ve kontrollu dogrulamalar bu ortamda yapilir.
- `.com` uzantili ortam production/canli yayin alanidir. Kullanici acikca "yayina al", "publish et", ".com'a yayinla" veya ayni anlama gelen net bir talimat vermedikce `.com` ortamina dokunma.
- `.com` icin DNS, hosting, FTP, CI/CD, build ciktisi, ortam degiskeni, Supabase production baglantisi veya deployment ayari degistirme; yayin niyeti kullanicidan acikca gelmelidir.
- `.info` ortaminda yapilan test veya basarili build, kendiliginden `.com` yayini anlamina gelmez. Test sonucu ne kadar basarili olursa olsun production adimi icin kullanicidan ayrica onay bekle.
- `.info` yayini, aksi kullanici tarafindan acikca istenmedikce `.com` ile ayni `main` kaynak agacini temel alir. Eski veya ayri bir teklif reposunun (`alihanylmz/uzalteklif` gibi) `info` dali yayin kaynagi olarak kullanilmaz.
- `.info` icin `test` dalini guncellemeden once dalin `uzalteklif` kaynaklarini icerdigini ve hedef agacin `main` ile beklenen farklarini kontrol et. Dali geri alma veya esitleme isleminden once mevcut test gecmisini tarihli bir yedek dalda koru.
- Uzal Teklif stok/urun katalog ana gorunumu elektronik tablo duzeninde kalir. Kullanici acikca istemedikce kart veya urun karti grid gorunumune geri donulmez; `.info` ve `.com` bu temel gorunumde uyumlu tutulur.
- Ortam karisikligi riski varsa isleme baslamadan once hangi domainin hedeflendigini netlestir. Ozellikle veri yazan, migration calistiran, bildirim gonderen veya kullaniciya gorunen yayin yapan islemlerde hedef ortami sonuc mesajinda belirt.
- Kullanici tarafindan daha once belirtilen proje kurallari bu dosyada kaynak kabul edilir. Yeni bir kural soylendiginde, kalici proje davranisi olacaksa bu dosyaya ekle ve mevcut kurallarla celismeyecek bicimde konumlandir.

## Projeyi Tanima

Gorevle ilgili oldugunda once su kaynaklari oku:

- `README.md`: desteklenen yerel calistirma komutlari.
- `docs/project-roadmap-and-gdrive-backup.md`: proje mevcut durumu, eksikler ve Google Drive Otomatik PDF Yedekleme mimarisi (ZORUNLU OKUNMALIDIR).
- `docs/technical-overview.md`: klasor sorumluluklari ve servis sinirlari.
- `docs/permission-matrix.md`: roller ve yetkiler.
- `docs/ticket-lifecycle.md`: is emri durum gecisleri.
- `docs/release-process.md`: surum ve yayin sureci.

Temel klasor sorumluluklari:

- `lib/main.dart`: uygulama baslatma, yapilandirma, kimlik dogrulama kapisi ve tema.
- `lib/config`: derleme ve calisma zamani yapilandirmasi.
- `lib/core`: loglama gibi ortak altyapi.
- `lib/features`: ozellik bazli uygulama ve veri katmanlari.
- `lib/models`: paylasilan domain modelleri, enumlar ve sabitler.
- `lib/pages`: ekranlar ve UI orkestrasyonu.
- `lib/services`: sayfalarin kullandigi mevcut servis/facade katmani.
- `lib/widgets`: tekrar kullanilan UI bilesenleri.
- `lib/theme`: renkler, tipografi ve uygulama temasi.
- `supabase`: veritabani ve Edge Function kaynaklari.

## Mimari Kurallar

- Yeni kodu, sorumluluguna uygun mevcut klasore yerlestir. Yeni bir mimari katman ancak gercek bir ihtiyac varsa eklenebilir.
- Sayfa widget'larinda dogrudan ve karmasik veri erisimi biriktirme; mevcut repository/service sinirlarini kullan.
- Is emri islemlerinde `TicketRepository`, `TicketNotificationCoordinator` ve geriye uyumlu `TicketService` sorumluluklarini koru.
- Is emri durumlari icin kanonik `TicketStatus` tanimini kullan; ayni durumlari string listeleriyle yeniden tanimlama.
- Rol ve yetki kontrollerini sadece UI gorunurlugune birakma. Mevcut servis, Supabase RLS ve `docs/permission-matrix.md` kurallariyla uyumlu tut.
- Mevcut public API'leri ve veri sozlesmelerini gereksiz yere bozma. Zorunlu bir kirici degisiklikte tum kullanimlari ve testleri birlikte guncelle.
- Tekrarlanan kodu ancak anlamli bir ortak davranis varsa ayir; tek kullanim icin gereksiz soyutlama olusturma.
- Platforma ozel davranista `lib/platform` ve mevcut kosullu calistirma kaliplarini kullan. Windows, Android, iOS ve web etkilerini kontrol et.

## Supabase ve Veri Guvenligi

- Supabase auth, tablo, storage ve function kullanimlarinda mevcut servis desenlerini izle.
- OneSignal bildirim gonderimini istemciye tasima; gonderim `send-notification` Edge Function uzerinden sunucu tarafinda kalmalidir.
- Client tarafina `service_role` anahtari veya baska ayricalikli kimlik bilgisi koyma.
- Yeni ya da degisen sorgularda kullanici, takim ve partner kapsamini koru. Ozellikle `partner_user` verileri `partner_id` ve RLS ile sinirli kalmalidir.
- Migration'lari tekrar calistirilabilir ve mevcut veriyi koruyacak bicimde tasarla. Veri silen veya geri donusu zor SQL icin kullanicidan acik onay al.
- Tablo/kolon/RPC degisikliginde ilgili Dart modellerini, servisleri, dokumani ve testleri birlikte degerlendir.
- Hatalarda hassas veri veya ham kimlik bilgisi loglama. Kullaniciya anlasilir hata goster, teknik ayrintiyi kontrollu logla.

## Dart ve Flutter Kod Standartlari

- Dart 3.7.2 ve `flutter_lints` 5 kurallarina uy.
- Mevcut dosyanin isimlendirme, import ve sinif duzenini takip et. Dart adlandirma kurallarini kullan: dosyalarda `snake_case`, tiplerde `UpperCamelCase`, uye ve fonksiyonlarda `lowerCamelCase`.
- Null safety'yi koru; gereksiz `!`, `dynamic` ve kontrolsuz cast kullanma.
- Asenkron islemlerde `await`, hata ve yasam dongusu davranisini acik tut. UI'da `await` sonrasinda `context` kullanmadan once gerektiginde `mounted` kontrolu yap.
- Widget'lari okunabilir ve tek sorumluluklu tut. Buyuk `build` metotlarini, gercekten ayri bir UI sorumlulugu oldugunda mevcut stile uygun widget'lara bol.
- `const` kullanilabilen widget ve degerlerde `const` tercih et; fakat okunabilirligi bozacak mekanik degisiklik yapma.
- Kullaniciya gorunen metinlerde projenin mevcut Turkce dilini ve terminolojisini koru.
- Aciklayici olmayan yorum ekleme. Yalnizca koddan anlasilamayan karar veya kisiti kisa bir yorumla belirt.
- Yeni paket eklemeden once SDK'nin ve mevcut bagimliliklarin ayni ihtiyaci karsilayip karsilamadigini kontrol et. Paket eklemek gerekiyorsa nedenini belirt ve `pubspec.lock` dosyasini uyumlu guncelle.

## UI ve Tema

- Renk, tipografi ve ortak stiller icin `lib/theme/app_theme.dart` ile `lib/theme/app_colors.dart` kaynaklarini kullan; ekran icinde rastgele sabit renkler cogaltma.
- Mevcut ortak widget'lari yeniden kullan. Benzer bir bilesen varsa ikinci bir varyant olusturmadan once onu genisletmenin uygunlugunu degerlendir.
- Masaustu, mobil ve web yerlesimlerini dikkate al. Metin tasmasi, klavye acilmasi, dar ekran ve yukleniyor/bos/hata durumlarini ele al.
- Formlarda dogrulama, kaydetme sirasinda tekrar tiklamayi engelleme ve basari/hata geri bildirimi sagla.
- Erisilebilirligi koru: yeterli kontrast, anlamli etiketler, dokunma hedefleri ve klavye ile kullanilabilirlik.
- Performansli liste bilesenlerini (`ListView.builder` gibi) kullan; `build` icinde ag sorgusu, dosya islemi veya agir hesaplama yapma.

## Dogrulama ve Test

- Degisiklikten sonra dokunulan Dart dosyalarini `dart format` ile bicimlendir.
- En azindan ilgili kapsami analiz et; uygun oldugunda tam `flutter analyze` calistir.
- Davranis degisikliginde mevcut testleri guncelle veya odakli yeni test ekle. Hata duzeltmelerinde mumkunse hatayi once yeniden uretecek bir regresyon testi yaz.
- Test ve calistirma icin repodaki desteklenen wrapper'i kullan:
  - `./run_local.bat test`
  - `./run_local.bat`
  - `./run_local.bat build-web`
- `env.txt` icerigini ciktiya basma veya repoya yeni sirlarla birlikte ekleme; wrapper gerekli `--dart-define` degerlerini kendisi yukler.
- Yalnizca ilgili dosyalari bicimlendir. Tum repoyu gereksiz yere yeniden bicimlendirme.
- Tam test veya analiz calistirilamadiysa bunu sonuc mesajinda acikca belirt; calistirilmamis kontrolu basarili gibi sunma.

## Degisiklik Sonu Kontrol Listesi

Her gorevin sonunda sunlari kontrol et:

1. Kullanici istegi tamamen karsilandi mi?
2. Yetki, veri kapsami ve RLS davranisi korundu mu?
3. Platform ve responsive etkiler dusunuldu mu?
4. Format, analiz ve ilgili testler calisti mi?
5. Ilgisiz dosyalar degismeden kaldi mi?
6. Yeni gizli bilgi, gecici dosya veya uretilmis build ciktisi eklenmedi mi?
7. Sonuc, degisen dosyalar ve yapilan dogrulamalar kullaniciya kisa ve dogru bicimde bildirildi mi?
