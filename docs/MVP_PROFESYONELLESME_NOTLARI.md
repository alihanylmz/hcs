# MVP profesyonelleşme notları

**Tarih:** 8 Eylül 2026
**Kaynak:** Faz 3.4 çalışması sırasında kod incelemesi ve karşılıklı değerlendirme.

Bu dosya `TEKLIF_SATIS_CARI_SISTEMI_CALISMA_FAZLARI.md`'nin yerine geçmez. Oradaki
fazlar geçerli; burada MVP'yi (çalışma arkadaşlarının günlük kullanımı) profesyonel
hale getirmek için tespit edilen **somut, doğrulanmış** eksikler var.

Tekrar eden bir örüntü çıktı: **veri modeli hazır, ekranda karşılığı yok.** Aşağıdaki
maddelerin çoğu yeni tablo veya alan gerektirmiyor.

---

## 1. Onay sistemi kaldırılırken durum sözlüğü temizlenmeli — EN KRİTİK

`QuoteStatus` enum'unun sonunda geçici takma adlar duruyor:

    // Eski kod yolları için geçici derleme uyumluluğu.
    static const pending  = approvalPending;
    static const accepted = won;
    static const rejected = lost;

Kod iki dil konuşuyor: bazı ekranlar `accepted/rejected/approved`, model ise
`won/lost/sent` diyor. Takma adlar aynı değere işaret ettiği için şu an çalışıyor.

**Onay kaldırılınca sessizce bozulacak yerler:**

- `my_workspace_page.dart:134` → `approvedQuotes = quotes.where(status == approved)`
  Masam'daki **Aksiyon Bekleyen Teklifleriniz** kartının tamamı (3+ gün cevapsız
  kırmızı alarm, e-posta atılmamışlar, cevap bekleyenler) bunun üstüne kurulu.
  Hiçbir teklif `approved` olmayacağı için kart **boşalır**.
- `cari_detail_page.dart` → Açık fırsat kartı da `status == approved` sayıyor,
  **sıfır** gösterecek.

**Yapılacak:** akışı `Taslak → Gönderildi → (Görüldü) → Pazarlık → Kazanıldı/Kaybedildi`
olarak kur, `approvalPending`/`approved` adımını çıkar, takma adları sil, Masam ve
cari detayını `sent` üzerine bağla.

---

## 2. Teklif hangi yetkiliye verildiğini bilmiyor

`CariAccount.contacts` çoklu yetkili tutuyor, cari detayında listeleniyor,
`ensureContactExists` teklif yazarken otomatik ekliyor. Buraya kadar iyi.

Ama `Quote` modelinde **`customerContactId` yok**. Yetkili bilgisi teklifin içine
kopyalanıyor: `customerName`, `customerContactTitle`, `customerPhone`, `customerEmail`.

**Sonuçları:**
- Ahmet Bey'e kaç teklif verdik, kaçını kazandık sorusu sorulamıyor
- Yetkili firmadan ayrılınca tekliflerinin kime devrolduğu belirsiz

**Yapılacak:** `Quote`'a `customerContactId` ekle. Mevcut metin alanları belgede
kalsın (teklif basıldığı günkü bilgiyi taşımalı); yeni alan yalnızca hangi yetkili
kaydına ait olduğunu söylesin.

---

## 3. Teklif takip tablosu çok az bilgi gösteriyor

`quotes_page.dart` → `_QuoteTable` sütunları: **Teklif No, Cari, Başlık, Tarih, Durum.**
Tutar yok, sorumlu yok.

Ayrıca `_QuoteSummaryCard` (satır ~1742) avatar ve "Sorumlu: X" gösteren güzel bir kart
ama **hiçbir yerden çağrılmıyor — ölü kod.**

Satıra bakan biri şunları soramıyor, **hepsinin verisi mevcut:**

| Soru | Alan | Durum |
|---|---|---|
| Kaç TL? | toplam hesaplanabiliyor | sütun yok |
| Kim hazırladı? | `createdByName` | ölü kartta |
| Gönderildi mi? | `emailSentAt` | sütun yok |
| Müşteri açtı mı? | `emailViewedAt` | 1 yerde |
| Geçerlilik ne zaman doluyor? | `validUntil` | **UI'da hiç kullanılmıyor** |
| Kaçıncı revizyon? | `revisionCount` | gösterilmiyor |

**Önerilen sütunlar:** `Kod · Cari · Başlık · Sorumlu · Tutar · Durum · Son Hareket · uyarı`

- **Tutar** en çok eksikliği hissedilen sütun; satış listesinde para görünmeli
- **Son hareket**: "5 gün önce gönderildi", "12 gündür bekliyor"
- **Uyarı**: geçerlilik dolmuş / 3+ gün cevapsız / hiç gönderilmemiş (Masam mantığı,
  satır bazında)

Ayrıca: satır yoğunluğu artırılmalı (kurumsal tablolar sıkıdır), sütuna göre sıralama,
durum rozetlerinde renk tutarlılığı.

---

## 4. Kullanılmayan takip alanları

Faz 2'de eklenmiş, veritabanında duruyor, **UI'da hiç kullanılmıyor:**

| Alan | Ne işe yarar |
|---|---|
| `validUntil` | Teklif ne zaman düşüyor — hem müşteriye baskı hem bu ölü sinyali |
| `nextActionAt` | 3 gün sonra ara — Masam'ın sabit 3 gün kuralından çok daha iyi |
| `expectedCloseAt` | Beklenen kapanış — pipeline ve takvim için |
| `lossReasonCode` | Kayıp nedeni (fiyat/termin/rakip/iptal) — neden kaybediyoruz sorusunun cevabı burada birikir |

Dördü de forma ve Masam'a bağlanmalı. Yeni migration gerekmiyor.

---

## 5. Masam yenileme: takvim ve notlar

**Sıra önemli:** takvim tek başına değersiz — üstünde gösterilecek tarih verisi yoksa
boş kutu olur. Önce madde 4'teki alanlar kullanılır hale gelmeli, takvim ondan sonra
kendiliğinden anlamlanır ("12 Mart'ta 3 teklifin geçerliliği doluyor").

**Notlar serbest değil, bağlı olmalı.** Masaya yapışık serbest not kaybolur; cariye
veya teklife bağlı not altı ay sonra o kaydı açınca karşına çıkar. Bu zaten yol
haritasındaki **Faz 6.4 Aktivite ve görevler** (arama / e-posta / WhatsApp / toplantı /
not türleri, sorumlu ve son tarih).

---

## 6. Mükerrer cari — bugün açılan risk

Faz 3.4'te otomatik cari açma eklendi. Eşleştirme **birebir isim** karşılaştırması
(`CariRepository.findByCompanyName`, büyük/küçük harf duyarsız). "Uzal Teknik" ile
"Uzal Teknik Ltd" ayrı cari oluyor. Liste her gün biraz daha bozuluyor ve veri
bozulması geri alması en pahalı şey.

Yol haritasında **Faz 6.2** tamamını kapsıyor. Beklemeden yapılabilecek ucuz kısım:

1. **Vergi numarası kimlik çıpası** — Türkiye'de firmanın gerçek benzersiz anahtarı;
   doluysa önce ona bak
2. **İsim normalizasyonu** — ltd / a.ş. / san / tic / şti ekleri ve noktalama atılarak
   karşılaştır
3. **Açmadan önce uyar** — buna benzeyen 2 cari var, birini mi kastettin

Birleştirme aracı sonra gelebilir.

---

## 7. Hiçbir şey deploy'u durdurmuyor

`deploy-test-site.yml` **test de analyze de çalıştırmıyor**; sadece derleyip FTP'ye
atıyor. `flutter_ci.yml` var ama yalnızca `main` ve PR'larda — `test` dalında hiç
çalışmıyor.

Yani 161 test var ama **hiçbiri canlıya çıkmayı engelleyemiyor.** Derlenen her şey
yayına gidiyor.

**Yapılacak:** deploy adımından önce `flutter analyze` ve `flutter test`. Önce şu 2
kırık testi düzeltmek gerekiyor, yoksa deploy kilitlenir:

- `test/widget_test.dart` → home screen renders offer flow
- `test/control_hardware_library_page_test.dart` → sıfır stoklu katalog araması

Bu iki hata `214c9e4`'ten beri var, bu çalışmadan önce de kırıktı.

---

## 8. Şema kayması

8 Eylül'de iki kez çarpıldı: `quotes_cari_id_fkey` canlıda vardı repoda yoktu,
`contacts` sütunu migration'da vardı canlıda yoktu. **Repo ile veritabanının aynı
olduğunu kimse garanti etmiyor**; hangi migration'ın uygulandığını tutan bir tablo yok.

---

## 9. Fırsat / pipeline — profesyonelin asıl eşiği

Program şu an çok iyi bir **teklif üreticisi**. Satış sistemi olmasının önündeki tek
büyük eksik fırsat kavramı (yol haritasında **Faz 6.3**).

Şu an teklif verdim var; bu iş hangi aşamada, ne zaman kapanır, kaç ihtimalle,
kaybettiysem neden yok. Bunlar olmadan Faz 7'deki raporlama da anlamsız kalır.

---

## Önerilen sıra

1. Deploy'a test kapısı (ve 2 kırık testi düzelt) — bugünkü işi korur
2. Onay kaldırma ve durum sözlüğü temizliği — yoksa takip ölür
3. Takip alanlarını (`validUntil`, `nextActionAt`, `lossReasonCode`) ekrana çıkar
4. Teklif tablosu sütunları ve ölü `_QuoteSummaryCard`'ı canlandır
5. Mükerrer cari önleme (vergi no, normalizasyon, uyarı)
6. `customerContactId`
7. Masam yenileme, takvim ve bağlı notlar (Faz 6.4)
8. Fırsat / pipeline (Faz 6.3)
