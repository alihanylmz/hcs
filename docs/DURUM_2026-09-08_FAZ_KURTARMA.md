# Durum notu — 8 Eylül 2026, Faz 3.x kurtarma

Bu dosya, 7-8 Eylül gecesi yapılan çalışmanın bıraktığı durumu anlatır.
Amacı, ertesi gün sohbet geçmişini kazmadan devam edebilmektir.

## Ne oldu

7 Eylül gecesi, Faz 3.3'ün derleme hatalarını çözmek için `test` dalında
`git reset --hard origin/main` çalıştırıldı. Bu komut dalı `6ad0878`'den
`214c9e4`'e geri aldı ve aradaki **98 dosyayı** çalışma dizininden sildi.

Silinen zincir:

```
214c9e4  origin/main
  └─ 6ad0878   Faz 3.1  (35 widget + 38 test + 4 servis + 6 doküman)
      └─ 53205fa … 8f28af2   Faz 3.2  (üç adımlı sihirbaz, 6 commit)
          └─ 2e75d01 … 075ba6b   Faz 3.3  (autosave, yarım)
```

Hiçbir commit kaybolmadı; hepsi reflog üzerinden erişilebilir durumda.

## Şu anki gerçek durum

| Faz | Nerede | Canlıda mı |
|---|---|---|
| 1 ve 2 (veritabanı işleri) | Supabase'de uygulanmış | evet |
| 1 ve 2 dokümanları + 8 migration dosyası | yalnızca `6ad0878` | — |
| 3.1 bileşen ayrımı (98 dosya) | yalnızca `6ad0878` | hayır |
| 3.2 üç adımlı sihirbaz | yalnızca `8f28af2` | **hayır** |
| 3.3 otomatik taslak | `faz-3.3-recovery` dalı | hayır |
| 3.4 cari dropdown + otomatik cari | `test` dalı (`b13f51d`) | **evet** |

Önemli: oturum boyunca "Faz 3.2 tamamlandı ve yayında" denmişti, **yanlıştı**.
Mevcut `quote_editor_page.dart` içinde `_currentStep` hiç geçmiyor; sihirbaz
canlıda yok.

## Numaralandırma çakışması

Kullanıcının yol haritasında (`TEKLIF_SATIS_CARI_SISTEMI_CALISMA_FAZLARI.md`)
**Faz 3.4 = "Hızlı kalem tablosu"**. Bu gece yapılan cari dropdown işine de
"Faz 3.4" adı verildi. Commit geçmişinde bu ad duruyor; gerçek 3.4 henüz
yapılmadı.

## 3.2 ile 3.4 birleştirme denemesinin sonucu

`8f28af2` ile `b13f51d` gerçek bir merge ile denendi:

- `quote_editor_page.dart` → 3 çakışma
- `schema.sql` → 1 çakışma (önemsiz, iki taraf da `cari_id` satırı)
- `cari_repository.dart`, `quote_repository.dart`, testler, migration → temiz

**Asıl risk çakışma sayısı değil.** Faz 3.2, `_buildQuickInfoFields()`
metodunu kaldırıyor; Faz 3.4'ün cari dropdown'u tam da o metodun içinde.
Merge sonrası kod derleniyor ve testler geçiyor, ama `_buildQuickInfoFields()`
hiçbir yerden çağrılmadığı için **dropdown ekranda görünmüyor** — sessiz bir
kayıp. Ayrıca 3.1/3.2 müşteri alanlarını
`quote_editor_customer_contact_fields.dart` widget'ına taşımış, 3.4'ün
değişiklikleri ise sayfa içinde satır içi.

Sonuç: `git merge` yetmez, 3.4'ün cari işi 3.2'nin yapısına **yeniden
yerleştirilmeli**.

## Faz 3.3 hakkında (bitti ama merge edilmedi)

`faz-3.3-recovery` dalında, yerelde doğrulandı (analyze temiz, testler
geçiyor, `flutter build web` derleniyor). Kurtarılan eski kodda bulunup
düzeltilen hatalar:

1. `connectivity_plus` v6 liste döndürüyor; tek enum ile karşılaştırıldığı
   için çevrimdışı algılama hiç çalışmıyordu.
2. `query.eq(...)` dönüş değeri atanmadan çağrılmıştı; filtre hiç
   uygulanmıyordu, bu da **her manuel kayıtta** çakışma tespitini sessizce
   kapatırdı.
3. `AUTOSAVE` kaynağı teklif notuna "Cikti bicimi" etiketi ekliyordu; not her
   açılış/kayıt döngüsünde büyürdü.
4. Kurtarma anahtarı okuma ile yazmada farklıydı; yeni tekliflerde kurtarma
   hiç çalışmıyordu.

Ayrıca autosave **sunucuya yazmıyor**, yalnızca cihaza yazıyor. Sebep:
`quotes` tablosundaki `quotes_capture_revision` (koşulsuz, her UPDATE'te
revizyon geçmişine snapshot), `quotes_audit_log` ve `quotes_sync_line_items`
trigger'ları. 12 saniyede bir sunucuya yazmak revizyon geçmişini sahte
kayıtlarla doldururdu.

## Faz 3.4'ün eksiği

Auto-create yolunun testi **yok**. Planındaki F adımı yarım kaldı: yazılan
widget testi var olmayan bir `ValueKey('btn-tamamla')` kontrolü içinde
assert ettiği için hiçbir şey sınamıyordu, silindi ve yerine bir şey
konmadı. Şu an yalnızca `findByCompanyName` birim testleri var.

## Yarın için önerilen sıra

1. **Karar:** 3.1 ve 3.2 geri gelecek mi? (3.2'nin sihirbazı hiç canlıya
   çıkmadı; istenmiyorsa yalnızca 3.1 geri alınabilir.)
2. Geri gelecekse: `8f28af2`'den yeni bir dal açılır, 3.4'ün cari işi bu
   yapıya yeniden yerleştirilir, **dropdown'ın gerçekten göründüğü elle
   doğrulanır**.
3. Sonra 3.3 aynı dalın üstüne uyarlanır.
4. En son 3.4'ün eksik testleri yazılır.

Monolit üzerine yeni iş eklendikçe bu yeniden yerleştirme maliyeti artar;
bu yüzden 1. madde diğer her şeyden önce gelir.

## Faydalı komutlar

```
git show 6ad0878 --stat            # Faz 3.1 içeriği
git show 8f28af2:<dosya>           # Faz 3.2'deki hali
git worktree add <dizin> 8f28af2   # bozmadan incelemek için
```

Yerel doğrulama (flutter PATH'te değil):

```
export PATH="/c/flutter/bin:$PATH"
cd uzalteklif && flutter analyze && flutter test
```
