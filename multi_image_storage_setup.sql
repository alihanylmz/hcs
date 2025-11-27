-- 1. ticket_notes tablosuna çoklu resim URL'lerini saklamak için sütun ekle (Text Array)
ALTER TABLE public.ticket_notes 
ADD COLUMN IF NOT EXISTS image_urls text[];

-- 2. Eğer eski 'image_url' sütunu varsa, verileri kaybetmemek için koruyabiliriz 
-- ama şimdilik yeni sisteme geçiyoruz.

-- 3. STORAGE (Dosya Depolama) Ayarları
-- 'ticket-files' bucket'ı yoksa oluşturulmalıdır (SQL ile bucket oluşturulamaz, panelden oluşturun)
-- Ancak bucket'ın "Public" olduğundan emin olun.

-- Yükleme Politikası (Herkes yükleyebilir - Auth şartı eklenebilir)
create policy "Herkes resim yükleyebilir 1ro9_0"
on storage.objects for insert
to public
with check ( bucket_id = 'ticket-files' );

-- Görüntüleme Politikası (Herkes resimleri görebilir)
create policy "Herkes resimleri görebilir 1ro9_1"
on storage.objects for select
to public
using ( bucket_id = 'ticket-files' );

-- Silme/Güncelleme Politikası (Sadece authenticated kullanıcılar)
create policy "Kullanıcılar işlem yapabilir 1ro9_2"
on storage.objects for all
to authenticated
using ( bucket_id = 'ticket-files' )
with check ( bucket_id = 'ticket-files' );

