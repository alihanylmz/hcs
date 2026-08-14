-- Inovaks partnerini partners tablosuna ekleme (idempotent insert)
insert into public.partners (name, contact_info)
select 'İnovaks Isıtma Soğutma Klima San. ve Tic. A.Ş.', 'İnovaks Kurumsal Partner'
where not exists (
  select 1 from public.partners where lower(name) like '%inovaks%'
);
