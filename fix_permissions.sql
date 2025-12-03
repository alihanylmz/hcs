-- Önce hatalı politikayı silelim
DROP POLICY IF EXISTS "Partnerler sadece kendi işlerini görür_v2" ON public.tickets;
DROP POLICY IF EXISTS "Partnerler sadece kendi işlerini görür" ON public.tickets;

-- YENİ VE DOĞRU POLİTİKA
-- Kural:
-- 1. Admin, Yönetici (manager) ve Teknisyen (technician) -> HER ŞEYİ GÖRÜR.
-- 2. Partner Kullanıcısı (partner_user) -> Sadece kendisine (partner_id) atanmış işleri görür.

CREATE POLICY "Global Erisim Politikasi" ON public.tickets
FOR SELECT
USING (
  -- 1. İç Ekip Kontrolü (Admin, Manager, Technician)
  (auth.uid() IN (
    SELECT id FROM public.profiles 
    WHERE role IN ('admin', 'manager', 'technician')
  ))
  
  OR
  
  -- 2. Partner Kontrolü
  (partner_id IN (
    SELECT partner_id FROM public.profiles 
    WHERE id = auth.uid()
    AND role = 'partner_user' -- Sadece rolü partner_user ise bu kural çalışsın
  ))
);

