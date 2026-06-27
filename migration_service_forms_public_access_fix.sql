-- Public service form links are opened by anonymous customers.
-- The form query joins service_form_templates, so anon also needs read access
-- to active templates; otherwise the public page cannot load the form content.

DROP POLICY IF EXISTS "templates_select_anon_active" ON public.service_form_templates;
CREATE POLICY "templates_select_anon_active"
  ON public.service_form_templates FOR SELECT
  TO anon
  USING (is_active = true);
