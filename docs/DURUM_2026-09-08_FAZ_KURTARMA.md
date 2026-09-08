# Durum notu — 8 Eylül 2026, Faz 3.x kurtarma (TAMAMLANDI)

7-8 Eylül gecesi `test` dalında çalıştırılan `git reset --hard origin/main`,
dalı `6ad0878`'den `214c9e4`'e alarak **98 dosyayı** sildi: Faz 3.1'in bileşen
ayrımı, Faz 3.2'nin üç adımlı sihirbazı, Faz 1/2 dokümanları ve 8 migration.
Hiçbir commit kaybolmadı; hepsi reflog'da duruyordu.

8 Eylül sabahı üç aşamada geri alındı ve tek dalda birleştirildi.

## Sonuç

| Faz | Durum |
|---|---|
| 3.1 bileşen ayrımı (97 dosya) | geri alındı |
| 3.2 üç adımlı sihirbaz | geri alındı, kırıkları düzeltildi |
| 3.3 otomatik yerel taslak | yeniden yazıldı, entegre edildi |
| 3.4 cari eşleştirme + otomatik cari | korundu, testleri tamamlandı |

Doğrulama: `flutter analyze` 0 hata/uyarı, **134 test geçiyor**,
`flutter build web` derleniyor. Kalan 2 test hatası (`control_hardware`,
`widget_test`) `214c9e4`'te de vardı, bu çalışmadan önce.

## Yol boyunca bulunan gerçek hatalar

**Faz 3.2 hiç derlenmiyormuş.** `8f28af2`, `_checkRequiredFields` metodunu
`_QuoteEditorPageState` yerine `_ParameterFieldEditor` içinde bırakmış; test
takımı hiç çalışamamış. Dolayısıyla 3.2'nin Adım E test güncellemeleri de hiç
koşmamış ve ikisi hatalıymış:
- Keşif testi teklif başlığını adım 1'de arıyordu (başlık adım 0'da).
- `_enableAdvanced` yardımcısı, ekran altında kalan toggle'a tıklıyordu; tıklama
  ıskalıyor ve gelişmiş seçenekler hiç açılmıyordu. `ensureVisible` eklendi.

**Faz 3.3'ün kurtarılan kodunda dört hata** vardı; hepsi düzeltildi:
`connectivity_plus` v6 liste döndürdüğü için çevrimdışı algılama hiç
çalışmıyordu; `query.eq(...)` dönüş değeri atanmadığı için çakışma tespiti her
manuel kayıtta sessizce kapanıyordu; `AUTOSAVE` kaynağı teklif notunu her
kayıtta büyütüyordu; kurtarma anahtarı okuma ile yazmada farklıydı.

## Faz 3.3 tasarım kararı

Otomatik taslak **sunucuya yazmaz**, yalnızca cihaza yazar. `quotes`
tablosundaki `quotes_capture_revision` (koşulsuz, her UPDATE'te revizyon
geçmişine snapshot), `quotes_audit_log` ve `quotes_sync_line_items`
trigger'ları yüzünden 12 saniyede bir sunucuya yazmak revizyon geçmişini sahte
kayıtlarla doldururdu. Cihazlar arası devam "Taslak Olarak Kaydet" butonuyla
zaten çalışıyor.

Gösterge bilerek "Kaydedildi" demez, "Taslak bu cihazda" der; aksi halde
kullanıcı teklifi sisteme kaydettiğini sanıp sekmeyi kapatabilir.

## Numaralandırma notu

Yol haritasında **Faz 3.4 = "Hızlı kalem tablosu"**. Bu gece cari dropdown
işine de "Faz 3.4" adı verildi ve commit geçmişinde öyle duruyor. Gerçek 3.4
henüz yapılmadı. Sıradaki fazlar: 3.4 hızlı kalem tablosu, 3.5 şablonlar,
3.6 güvenli kopyalama, 3.7 ana aksiyonları sadeleştirme.

## Yerel doğrulama

`flutter` PATH'te değil:

```
export PATH="/c/flutter/bin:$PATH"
cd uzalteklif && flutter analyze && flutter test
```
