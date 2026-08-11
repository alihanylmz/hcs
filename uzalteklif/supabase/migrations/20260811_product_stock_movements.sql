-- Is Takip stok modulu, Uzal Teklif urun kartlarini ve stok adedini kullanir.
-- Teklif kayitlariyla bag kurmadan urun bazli giris/cikis gecmisi tutulur.

alter table public.stock_movements
add column if not exists product_id text references public.products(id) on delete cascade;

alter table public.stock_movements
alter column inventory_id drop not null;

create index if not exists stock_movements_product_id_idx
on public.stock_movements (product_id);

create or replace function public.register_product_stock_movement(
    p_product_id text,
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
    v_before numeric(14,2);
    v_after numeric(14,2);
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

    select stock_quantity
    into v_before
    from public.products
    where id = p_product_id
    for update;

    if not found then
        raise exception 'Urun stok kaydi bulunamadi.';
    end if;

    if p_movement_type = 'in' then
        v_after := v_before + p_quantity;
    else
        v_after := v_before - p_quantity;
    end if;

    if v_after < 0 then
        raise exception 'Stok yetersiz! Mevcut: %', v_before;
    end if;

    update public.products
    set stock_quantity = v_after,
        updated_at = timezone('utc', now())
    where id = p_product_id;

    insert into public.stock_movements (
        product_id,
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
        p_product_id,
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

grant execute on function public.register_product_stock_movement(
    text,
    text,
    integer,
    text,
    text,
    text
) to authenticated;
