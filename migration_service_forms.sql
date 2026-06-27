-- ============================================================
-- Servis Öncesi Onay Formu - Migration
-- Tarih: 2026-06-27
-- ============================================================

-- 1. Form Şablonları Tablosu
-- Yöneticiler tarafından oluşturulan form şablonları (Jetfan, Nem Alma, AHU vb.)
CREATE TABLE IF NOT EXISTS public.service_form_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,                       -- "Jetfan Servis Formu"
  description TEXT,                                -- Kısa açıklama (opsiyonel)
  content_text TEXT NOT NULL DEFAULT '',           -- Müşteriye gösterilecek bilgilendirme metni
  checkboxes  JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [{"label":"...", "required":true}, ...]
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_by  UUID REFERENCES auth.users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Ticket'a Bağlı Gönderilen Formlar Tablosu
-- Her gönderilen form için bir kayıt oluşturulur.
CREATE TABLE IF NOT EXISTS public.ticket_service_forms (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id     UUID NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  template_id   UUID NOT NULL REFERENCES public.service_form_templates(id),
  status        TEXT NOT NULL DEFAULT 'pending'    -- pending | signed | cancelled
                  CHECK (status IN ('pending', 'signed', 'cancelled')),
  -- Müşteri tarafından doldurulan veriler
  customer_name    TEXT,
  signature_data   TEXT,                           -- Base64 PNG imzası
  checked_items    JSONB DEFAULT '[]'::jsonb,      -- Işaretlenen madde indexleri
  customer_ip      TEXT,                           -- Onay anındaki IP
  signed_at        TIMESTAMPTZ,                    -- İmzalanma zamanı
  -- Admin verileri
  created_by    UUID REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cancelled_at  TIMESTAMPTZ,
  cancel_reason TEXT
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.service_form_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ticket_service_forms ENABLE ROW LEVEL SECURITY;

-- Şablonlar: Oturum açmış kullanıcılar okuyabilir
DROP POLICY IF EXISTS "templates_select_authenticated" ON public.service_form_templates;
CREATE POLICY "templates_select_authenticated"
  ON public.service_form_templates FOR SELECT
  TO authenticated
  USING (true);

-- Şablonlar: Sadece admin/manager oluşturabilir, güncelleyebilir, silebilir
DROP POLICY IF EXISTS "templates_insert_admin" ON public.service_form_templates;
CREATE POLICY "templates_insert_admin"
  ON public.service_form_templates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'manager')
    )
  );

DROP POLICY IF EXISTS "templates_update_admin" ON public.service_form_templates;
CREATE POLICY "templates_update_admin"
  ON public.service_form_templates FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'manager')
    )
  );

DROP POLICY IF EXISTS "templates_delete_admin" ON public.service_form_templates;
CREATE POLICY "templates_delete_admin"
  ON public.service_form_templates FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'manager')
    )
  );

-- Ticket formları: Oturum açmış kullanıcılar okuyabilir
DROP POLICY IF EXISTS "ticket_forms_select_authenticated" ON public.ticket_service_forms;
CREATE POLICY "ticket_forms_select_authenticated"
  ON public.ticket_service_forms FOR SELECT
  TO authenticated
  USING (true);

-- Ticket formları: ANONİM kullanıcılar sadece pending formu güncelleyebilir (müşteri imzası)
-- Bu kritik: Müşteri link üzerinden geldiğinde anonymous kullanıcı olarak işlem yapar
DROP POLICY IF EXISTS "ticket_forms_select_anon" ON public.ticket_service_forms;
CREATE POLICY "ticket_forms_select_anon"
  ON public.ticket_service_forms FOR SELECT
  TO anon
  USING (status = 'pending');  -- Sadece bekleyen formlar anonim erişilebilir

DROP POLICY IF EXISTS "ticket_forms_update_anon" ON public.ticket_service_forms;
CREATE POLICY "ticket_forms_update_anon"
  ON public.ticket_service_forms FOR UPDATE
  TO anon
  USING (status = 'pending')   -- Sadece pending formları güncelleyebilir
  WITH CHECK (status = 'signed'); -- Sadece 'signed' yapabilir (iptal edemez)

-- Ticket formları: Authenticated kullanıcılar oluşturabilir
DROP POLICY IF EXISTS "ticket_forms_insert_authenticated" ON public.ticket_service_forms;
CREATE POLICY "ticket_forms_insert_authenticated"
  ON public.ticket_service_forms FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Ticket formları: Admin/Manager iptal edebilir
DROP POLICY IF EXISTS "ticket_forms_cancel_admin" ON public.ticket_service_forms;
CREATE POLICY "ticket_forms_cancel_admin"
  ON public.ticket_service_forms FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- Supabase Storage Bucket (imzalar için)
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('service-signatures', 'service-signatures', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Storage: Anonim kullanıcılar imza yükleyebilir
DROP POLICY IF EXISTS "signatures_upload_anon" ON storage.objects;
CREATE POLICY "signatures_upload_anon"
  ON storage.objects FOR INSERT
  TO anon
  WITH CHECK (bucket_id = 'service-signatures');

-- Storage: Herkes okuyabilir (link paylaşımı için)
DROP POLICY IF EXISTS "signatures_read_public" ON storage.objects;
CREATE POLICY "signatures_read_public"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'service-signatures');

-- Storage: Authenticated kullanıcılar silebilir (yönetici)
DROP POLICY IF EXISTS "signatures_delete_admin" ON storage.objects;
CREATE POLICY "signatures_delete_admin"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'service-signatures');

-- ============================================================
-- Başlangıç Form Şablonları (Örnek veriler)
-- ============================================================
INSERT INTO public.service_form_templates (name, description, content_text, checkboxes)
VALUES
  (
    'Jetfan Servis Formu',
    'Jetfan ürünleri için servis öncesi hazırlık kontrol formu',
    E'Sayın Müşterimiz,\n\nHizmetinizde bulunmaktan memnuniyet duyarız. Servis ekibimizin verimli çalışabilmesi ve gereksiz zaman/maliyet kayıplarının önüne geçilebilmesi için aşağıdaki şartların saha ziyaretinden önce sağlanmış olması gerekmektedir.\n\nBu formu imzalayarak servis talebi oluşturuyorsunuz. Belirtilen şartların sağlanmaması halinde saha ziyaret bedeli tarafınıza yansıtılabilir.',
    '[
      {"label": "Jetfan ünitesinin elektrik bağlantısının yapıldığını ve güç kaynağının hazır olduğunu teyit ediyorum.", "required": true},
      {"label": "Üniteye erişim için gerekli alan temizlenmiş ve platform/merdiven temin edilmiştir.", "required": true},
      {"label": "Servis yapılacak mekanda yetkili bir kişinin bulunacağını taahhüt ediyorum.", "required": true},
      {"label": "Şartların sağlanmaması durumunda saha ziyaret bedelinin tarafıma yansıtılacağını kabul ediyorum.", "required": true}
    ]'::jsonb
  ),
  (
    'Nem Alma Cihazı Servis Formu',
    'Endüstriyel nem alma üniteleri için servis öncesi hazırlık kontrol formu',
    E'Sayın Müşterimiz,\n\nNem alma cihazınız için servis randevusu oluşturulmaktadır. Teknik ekibimizin hizmetinize gelebilmesi için lütfen aşağıdaki hazırlık adımlarını tamamlayınız. Bu hazırlıklar hem servis süresini kısaltacak hem de ek maliyet oluşmasını önleyecektir.',
    '[
      {"label": "Nem alma ünitesinin elektrik bağlantısı sağlanmış ve cihaz erişilebilir konumdadır.", "required": true},
      {"label": "Cihazın drenaj hattı ve su tahliye borusunun konumu hakkında bilgi sahibiyim ve teknisyene yönlendirme yapabilirim.", "required": true},
      {"label": "Filtreler en son ne zaman temizlendiğini (veya hiç temizlenmediğini) biliyorum ve bu bilgiyi teknisyenle paylaşacağım.", "required": false},
      {"label": "Servis yapılacak mekanda yetkili bir kişinin bulunacağını taahhüt ediyorum.", "required": true},
      {"label": "Şartların sağlanmaması durumunda saha ziyaret bedelinin tarafıma yansıtılacağını kabul ediyorum.", "required": true}
    ]'::jsonb
  ),
  (
    'AHU (Hava İşleme Ünitesi) Servis Formu',
    'AHU ve klima santrali sistemleri için servis öncesi hazırlık formu',
    E'Sayın Müşterimiz,\n\nAHU sisteminiz için planladığımız servis ziyaretinden önce aşağıdaki teknik gereksinimlerin sağlanması zorunludur. Bu form, servis operasyonunun güvenli ve verimli yürütülebilmesi için bir ön teyit belgesidir.',
    '[
      {"label": "AHU ünitesinin ana enerji hattının erişilebilir olduğunu ve gerektiğinde yetkili tarafından enerji kesilebileceğini onaylıyorum.", "required": true},
      {"label": "Makine dairesi/teknik hacme erişim sağlanmıştır ve yetkili personel eşliğinde girilecektir.", "required": true},
      {"label": "Sistemin son bakım tarihi ve varsa arıza kayıtlarını teknisyenimizle paylaşabilirim.", "required": false},
      {"label": "Filtre, kayış, rulman gibi sarf malzemelerin değişimi gerekirse önceden bilgilendirileceğimi ve ek ücret söz konusu olabileceğini kabul ediyorum.", "required": true},
      {"label": "Servis sırasında sistemin bir süre durdurulabileceğini ve bu sürede ilgili alanın kullanımının kısıtlanacağını kabul ediyorum.", "required": true},
      {"label": "Şartların sağlanmaması durumunda saha ziyaret bedelinin tarafıma yansıtılacağını kabul ediyorum.", "required": true}
    ]'::jsonb
  ),
  (
    'Bina Otomasyonu Servis Formu',
    'BMS ve bina otomasyon sistemleri için servis öncesi hazırlık formu',
    E'Sayın Müşterimiz,\n\nBina otomasyon sisteminizin servis ve bakım çalışması için lütfen aşağıdaki bilgileri onaylayınız. Otomasyon sistemleri birden fazla teknik alt sistemi koordine ettiğinden, hazırlıksız bir saha ziyareti hem hizmet kalitesini düşürmekte hem de gereksiz maliyet yaratmaktadır.',
    '[
      {"label": "BMS/otomasyon panosuna erişim yetkisi verilmiş ve şifre/anahtar teknisyene teslim edilebilecek durumdadır.", "required": true},
      {"label": "Sistemin hangi alanları (HVAC, aydınlatma, güvenlik vb.) kapsadığını biliyorum ve bu bilgiyi teknik ekiple paylaşabilirim.", "required": true},
      {"label": "Servis sırasında kontrol kaybı yaşanabilecek alanlar hakkında ilgili birimler önceden bilgilendirilmiştir.", "required": true},
      {"label": "Sistemin lisans bilgileri, yazılım versiyonu ve son yedekleme tarihi hakkında bilgi sahibiyim.", "required": false},
      {"label": "Servis yapılacak mekanda yetkili ve teknik kararlar alabilen bir kişinin bulunacağını taahhüt ediyorum.", "required": true},
      {"label": "Şartların sağlanmaması durumunda saha ziyaret bedelinin tarafıma yansıtılacağını kabul ediyorum.", "required": true}
    ]'::jsonb
  )
ON CONFLICT DO NOTHING;
