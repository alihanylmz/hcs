-- Teknisyenlerin tüm işleri görebilmesini sağlayan RLS politikası

-- 1. Mevcut politikaları temizle (çakışmayı önlemek için)
DROP POLICY IF EXISTS "Global Erisim Politikasi" ON public.tickets;
DROP POLICY IF EXISTS "Technicians view all tickets" ON public.tickets;
DROP POLICY IF EXISTS "Partnerler sadece kendi işlerini görür" ON public.tickets;
DROP POLICY IF EXISTS "Partnerler sadece kendi işlerini görür_v2" ON public.tickets;

-- 2. Yeni kapsayıcı politika oluştur
CREATE POLICY "Global Erisim Politikasi" ON public.tickets
FOR SELECT
USING (
  -- Admin, Manager ve Technician tüm işleri görebilir
  (auth.uid() IN (
    SELECT id FROM public.profiles 
    WHERE role IN ('admin', 'manager', 'technician')
  ))
  
  OR
  
  -- Partner kullanıcıları sadece kendi partner_id'sine ait işleri görür
  (partner_id IN (
    SELECT partner_id FROM public.profiles 
    WHERE id = auth.uid()
    AND role = 'partner_user'
  ))
);

