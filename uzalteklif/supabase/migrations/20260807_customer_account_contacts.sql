-- Customer accounts contacts column and migration script
alter table public.customer_accounts
add column if not exists contacts jsonb not null default '[]'::jsonb;

-- Populate contacts array from existing contact_name if contacts is empty
update public.customer_accounts
set contacts = jsonb_build_array(
  jsonb_build_object(
    'name', contact_name,
    'title', contact_title,
    'phone', phone,
    'email', email,
    'is_primary', true
  )
)
where (contacts is null or jsonb_array_length(contacts) = 0)
  and (contact_name != '' or phone != '' or email != '');
