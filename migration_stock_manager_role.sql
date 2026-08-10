-- Stok yoneticisi rolunu stok hareketleri ve kullanici erisimi listelerine ekler.

drop policy if exists "stock_movements_insert_staff" on public.stock_movements;
create policy "stock_movements_insert_staff"
on public.stock_movements for insert
with check (
    auth.uid() in (
        select id from public.profiles
        where role in ('admin', 'manager', 'supervisor', 'stock_manager')
    )
);

create or replace function public.register_stock_movement(
    p_inventory_id bigint,
    p_movement_type text,
    p_quantity integer,
    p_reason text default null,
    p_destination text default null,
    p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_before integer;
    v_after integer;
    v_actor_role text;
begin
    select role::text
    into v_actor_role
    from public.profiles
    where id = auth.uid();

    if v_actor_role not in ('admin', 'manager', 'supervisor', 'stock_manager') then
        raise exception 'Bu islem icin stok yetkisi gerekir.';
    end if;

    if p_movement_type not in ('in', 'out') then
        raise exception 'Gecersiz stok hareketi.';
    end if;

    if p_quantity <= 0 then
        raise exception 'Adet 0dan buyuk olmali.';
    end if;

    select quantity
    into v_before
    from public.inventory
    where id = p_inventory_id
    for update;

    if not found then
        raise exception 'Stok kaydi bulunamadi.';
    end if;

    if p_movement_type = 'in' then
        v_after := v_before + p_quantity;
    else
        v_after := v_before - p_quantity;
    end if;

    if v_after < 0 then
        raise exception 'Stok yetersiz! Mevcut: %', v_before;
    end if;

    update public.inventory
    set quantity = v_after
    where id = p_inventory_id;

    insert into public.stock_movements (
        inventory_id,
        movement_type,
        quantity,
        quantity_before,
        quantity_after,
        reason,
        destination,
        note,
        created_by
    )
    values (
        p_inventory_id,
        p_movement_type,
        p_quantity,
        v_before,
        v_after,
        nullif(trim(coalesce(p_reason, '')), ''),
        nullif(trim(coalesce(p_destination, '')), ''),
        nullif(trim(coalesce(p_note, '')), ''),
        auth.uid()
    );
end;
$$;

grant execute on function public.register_stock_movement(
    bigint,
    text,
    integer,
    text,
    text,
    text
) to authenticated;
