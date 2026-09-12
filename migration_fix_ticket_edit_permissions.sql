-- Iki gercek hatayi duzeltir:
--
-- 1) ticket_notes tablosunda RLS acikken hicbir UPDATE politikasi yoktu.
--    Yani "not eklendikten sonra duzenlenememesi" HERKES icin (rolden
--    bagimsiz) gecerliydi - _showEditNoteDialog kod olarak dogruydu,
--    Supabase sessizce (veya PostgrestException ile) guncellemeyi
--    reddediyordu. Uygulamadaki mevcut yetki kurali zaten "not sahibi
--    veya admin/manager duzenleyebilir" (bkz. ticket_detail_page.dart,
--    canEditNote = isCurrentUser || _canModerateTicketNotes) - bu politika
--    onu veritabaninda da uygular.
--
-- 2) tickets tablosunun INSERT/UPDATE politikalarinda 'engineer' rolu hic
--    yoktu (sadece admin/manager/supervisor/technician). Ama uygulama
--    tarafinda (permission_service.dart) muhendis rolune hem createTicket
--    hem editTicket izni veriliyor - yani muhendis butonu goruyor, formu
--    dolduruyor, kaydet'e basiyor ve Supabase RLS sessizce/hatayla
--    reddediyordu. Uygulama ile veritabani kuralini hizalar.

drop policy if exists "ticket_notes_update_own_or_admin" on public.ticket_notes;
create policy "ticket_notes_update_own_or_admin"
  on public.ticket_notes for update
  using (
    auth.uid() = user_id
    or auth.uid() in (select id from public.profiles where role in ('admin', 'manager'))
  )
  with check (
    auth.uid() = user_id
    or auth.uid() in (select id from public.profiles where role in ('admin', 'manager'))
  );

drop policy if exists "tickets_insert_internal" on public.tickets;
create policy "tickets_insert_internal"
  on public.tickets for insert
  with check (
    auth.uid() in (
      select id from public.profiles
      where role = any (array['admin', 'manager', 'supervisor', 'engineer', 'technician'])
    )
  );

drop policy if exists "tickets_update_internal" on public.tickets;
create policy "tickets_update_internal"
  on public.tickets for update
  using (
    auth.uid() in (
      select id from public.profiles
      where role = any (array['admin', 'manager', 'supervisor', 'engineer', 'technician'])
    )
  )
  with check (
    auth.uid() in (
      select id from public.profiles
      where role = any (array['admin', 'manager', 'supervisor', 'engineer', 'technician'])
    )
  );
