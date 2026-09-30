-- ============================================================
-- RANCO CONECTA 2.0
-- Gastronomy: simple menu and table reservation requests
-- ============================================================

create table if not exists public.gastronomy_menu_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gastronomy_menu_categories_name_not_blank
    check (length(trim(name)) > 0)
);

create index if not exists gastronomy_menu_categories_business_idx
  on public.gastronomy_menu_categories(business_id, sort_order);

create table if not exists public.gastronomy_menu_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid references public.gastronomy_menu_categories(id) on delete set null,
  name text not null,
  description text,
  price integer not null default 0,
  image_path text,
  is_available boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gastronomy_menu_items_name_not_blank
    check (length(trim(name)) > 0),
  constraint gastronomy_menu_items_price_non_negative
    check (price >= 0)
);

create index if not exists gastronomy_menu_items_business_idx
  on public.gastronomy_menu_items(business_id, sort_order);

create index if not exists gastronomy_menu_items_category_idx
  on public.gastronomy_menu_items(category_id, sort_order);

create table if not exists public.gastronomy_table_reservations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reservation_date date not null,
  reservation_time time not null,
  guests integer not null,
  message text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint gastronomy_table_reservations_guests_check
    check (guests >= 1),
  constraint gastronomy_table_reservations_status_check
    check (status in ('pending', 'confirmed', 'rejected', 'cancelled'))
);

create index if not exists gastronomy_table_reservations_business_idx
  on public.gastronomy_table_reservations(business_id, reservation_date, reservation_time);

create index if not exists gastronomy_table_reservations_user_idx
  on public.gastronomy_table_reservations(user_id, created_at desc);

drop trigger if exists gastronomy_menu_categories_updated_at
  on public.gastronomy_menu_categories;

create trigger gastronomy_menu_categories_updated_at
before update on public.gastronomy_menu_categories
for each row
execute function public.set_updated_at();

drop trigger if exists gastronomy_menu_items_updated_at
  on public.gastronomy_menu_items;

create trigger gastronomy_menu_items_updated_at
before update on public.gastronomy_menu_items
for each row
execute function public.set_updated_at();

drop trigger if exists gastronomy_table_reservations_updated_at
  on public.gastronomy_table_reservations;

create trigger gastronomy_table_reservations_updated_at
before update on public.gastronomy_table_reservations
for each row
execute function public.set_updated_at();

alter table public.gastronomy_menu_categories enable row level security;
alter table public.gastronomy_menu_items enable row level security;
alter table public.gastronomy_table_reservations enable row level security;

drop policy if exists "public read published gastronomy menu categories"
  on public.gastronomy_menu_categories;

create policy "public read published gastronomy menu categories"
on public.gastronomy_menu_categories
for select
using (
  exists (
    select 1
    from public.businesses b
    where b.id = gastronomy_menu_categories.business_id
      and (
        b.publication_status = 'published'
        or public.user_can_manage_business(b.id)
      )
  )
);

drop policy if exists "managers manage gastronomy menu categories"
  on public.gastronomy_menu_categories;

create policy "managers manage gastronomy menu categories"
on public.gastronomy_menu_categories
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "public read published gastronomy menu items"
  on public.gastronomy_menu_items;

create policy "public read published gastronomy menu items"
on public.gastronomy_menu_items
for select
using (
  exists (
    select 1
    from public.businesses b
    where b.id = gastronomy_menu_items.business_id
      and (
        b.publication_status = 'published'
        or public.user_can_manage_business(b.id)
      )
  )
);

drop policy if exists "managers manage gastronomy menu items"
  on public.gastronomy_menu_items;

create policy "managers manage gastronomy menu items"
on public.gastronomy_menu_items
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "customers read own table reservations"
  on public.gastronomy_table_reservations;

create policy "customers read own table reservations"
on public.gastronomy_table_reservations
for select
using (user_id = auth.uid());

drop policy if exists "business managers read table reservations"
  on public.gastronomy_table_reservations;

create policy "business managers read table reservations"
on public.gastronomy_table_reservations
for select
using (public.user_can_manage_business(business_id));

create or replace function public.create_gastronomy_table_reservation(
  p_business_id uuid,
  p_reservation_date date,
  p_reservation_time time,
  p_guests integer,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_reservation_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Debes iniciar sesion para reservar.';
  end if;

  if p_reservation_date is null or p_reservation_time is null then
    raise exception 'La fecha y hora son obligatorias.';
  end if;

  if p_guests is null or p_guests < 1 then
    raise exception 'La cantidad de comensales no es valida.';
  end if;

  if not exists (
    select 1
    from public.businesses b
    where b.id = p_business_id
      and b.business_type = 'gastronomy'
      and b.publication_status = 'published'
  ) then
    raise exception 'El restaurante no esta disponible.';
  end if;

  insert into public.gastronomy_table_reservations (
    business_id,
    user_id,
    reservation_date,
    reservation_time,
    guests,
    message,
    status
  )
  values (
    p_business_id,
    v_user_id,
    p_reservation_date,
    p_reservation_time,
    p_guests,
    nullif(trim(p_message), ''),
    'pending'
  )
  returning id into v_reservation_id;

  return v_reservation_id;
end;
$$;

create or replace function public.confirm_gastronomy_table_reservation(
  p_reservation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.gastronomy_table_reservations r
  set status = 'confirmed'
  where r.id = p_reservation_id
    and r.status = 'pending'
    and public.user_can_manage_business(r.business_id);

  if not found then
    raise exception 'No tienes permiso para gestionar esta reserva o ya fue procesada.';
  end if;
end;
$$;

create or replace function public.reject_gastronomy_table_reservation(
  p_reservation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.gastronomy_table_reservations r
  set status = 'rejected'
  where r.id = p_reservation_id
    and r.status = 'pending'
    and public.user_can_manage_business(r.business_id);

  if not found then
    raise exception 'No tienes permiso para gestionar esta reserva o ya fue procesada.';
  end if;
end;
$$;

grant select
on public.gastronomy_menu_categories,
   public.gastronomy_menu_items
to anon, authenticated;

grant insert, update, delete, select
on public.gastronomy_menu_categories,
   public.gastronomy_menu_items
to authenticated;

grant select
on public.gastronomy_table_reservations
to authenticated;

grant execute on function public.create_gastronomy_table_reservation(
  uuid,
  date,
  time,
  integer,
  text
) to authenticated;

grant execute on function public.confirm_gastronomy_table_reservation(uuid)
to authenticated;

grant execute on function public.reject_gastronomy_table_reservation(uuid)
to authenticated;

-- ============================================================
-- END
-- ============================================================
