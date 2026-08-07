create or replace function public.sync_quote_line_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  item_id text;
  item_index integer;
  item_description text;
  item_quantity numeric;
  item_unit_price numeric;
  item_discount numeric;
begin
  delete from public.quote_line_items where quote_id = new.id;

  for item, item_index in
    select value, ordinality::integer
    from jsonb_array_elements(coalesce(new.items, '[]'::jsonb)) with ordinality
  loop
    item_id := coalesce(item->>'id', gen_random_uuid()::text);
    item_description := coalesce(item->>'description', '');
    item_quantity := coalesce((item->>'quantity')::numeric, 0);
    item_unit_price := coalesce((item->>'unit_price_tl')::numeric, 0);
    item_discount := coalesce((item->>'discount_rate')::numeric, 0);

    insert into public.quote_line_items (
      id,
      quote_id,
      code,
      description,
      quantity,
      unit,
      unit_price_tl,
      discount_rate,
      section_id,
      line_total_tl
    )
    values (
      new.id || ':' || item_id || ':' || item_index,
      new.id,
      split_part(item_description, ' - ', 1),
      item_description,
      item_quantity,
      coalesce(item->>'unit', ''),
      item_unit_price,
      item_discount,
      coalesce(item->>'section_id', ''),
      item_quantity * item_unit_price * (1 - (item_discount / 100))
    )
    on conflict (id) do update set
      quote_id = excluded.quote_id,
      code = excluded.code,
      description = excluded.description,
      quantity = excluded.quantity,
      unit = excluded.unit,
      unit_price_tl = excluded.unit_price_tl,
      discount_rate = excluded.discount_rate,
      section_id = excluded.section_id,
      line_total_tl = excluded.line_total_tl;
  end loop;

  return new;
end;
$$;
