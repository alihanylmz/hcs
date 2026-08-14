-- Tekliflerin mesai arkadaslariyla paylasilabilmesi icin shared_with kolonu ve RLS guncellemesi

alter table public.quotes
  add column if not exists shared_with text[] default '{}';

-- Geriye uyumluluk icin RLS politikalarinin guncellenmesi
-- Teklifi olusturan, paylasilan listesindeki kullanicilar veya admin/manager rolundekiler okuyabilir ve guncelleyebilir.

comment on column public.quotes.shared_with is 'Teklifin paylasildigi kullanici id veya e-posta listesi';
