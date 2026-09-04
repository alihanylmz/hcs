-- Tekliflerin mesai arkadaslariyla paylasilabilmesi icin shared_with kolonu
-- eklenir. Migration daha once yan projede tanimliydi; ana Supabase zincirine
-- de alinmazsa uygulama kayit sirasinda PGRST204 hatasina duser.

alter table public.quotes
  add column if not exists shared_with text[] default '{}';

comment on column public.quotes.shared_with is
  'Teklifin paylasildigi kullanici id veya e-posta listesi';
