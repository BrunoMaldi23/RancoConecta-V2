-- ============================================================
-- RANCO CONECTA 2.0
-- Controlled provider panel evolution: categories and lodging stay policies
-- ============================================================

-- 1. Add the five requested main categories without creating subcategories.

insert into public.categories (
  name,
  slug,
  icon_key,
  theme_key,
  active,
  sort_order
)
values
  ('Retiro de escombros', 'retiro-de-escombros', 'delete_sweep', 'forest', true, 17),
  ('Retiro de chatarra', 'retiro-de-chatarra', 'recycling', 'forest', true, 18),
  ('Servicios de fosas', 'servicios-de-fosas', 'water_drop', 'forest', true, 19),
  ('Hogar y mantenimiento', 'hogar-y-mantenimiento', 'home_repair', 'forest', true, 20),
  ('Inspección visual', 'inspeccion-visual', 'visibility', 'forest', true, 21)
on conflict (slug) do update set
  name = excluded.name,
  icon_key = excluded.icon_key,
  theme_key = excluded.theme_key,
  active = true,
  sort_order = excluded.sort_order;

update public.subcategories
set
  name = 'Atención de emergencia',
  description = 'Atención de emergencia, primeros auxilios y apoyo de salud.',
  icon_key = 'emergency'
where slug = 'home-emergencies'
  and exists (
    select 1
    from public.categories c
    where c.id = subcategories.category_id
      and c.slug = 'emergencies'
  );


-- 2. Lodging stay policies: nullable maximum nights means "no limit".

alter table public.lodging_details
  add column if not exists max_nights integer;

alter table public.lodging_details
  drop constraint if exists lodging_details_max_nights_valid;

alter table public.lodging_details
  add constraint lodging_details_max_nights_valid
  check (
    max_nights is null
    or (
      max_nights >= 1
      and max_nights >= min_nights
    )
  );


-- 3. Recreate booking RPC so min/max nights are enforced server-side.

create or replace function public.create_lodging_booking(
  p_business_id uuid,
  p_check_in date,
  p_check_out date,
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
  v_booking_id uuid;

  v_price integer;
  v_max_guests integer;
  v_included_guests integer;
  v_extra_price integer;
  v_min_nights integer;
  v_max_nights integer;

  v_nights integer;
  v_base integer;
  v_extra integer;
  v_total integer;

  v_name text;
  v_email text;

  v_blocked integer;
  v_conflicts integer;
begin

  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Debes iniciar sesion para reservar.';
  end if;

  if p_check_in is null
     or p_check_out is null
     or p_check_out <= p_check_in then
    raise exception 'Las fechas de la reserva no son validas.';
  end if;

  if p_guests is null or p_guests < 1 then
    raise exception 'La cantidad de huespedes no es valida.';
  end if;


  select
    ld.price_per_night,
    ld.max_guests,
    ld.included_guests,
    ld.extra_guest_price,
    ld.min_nights,
    ld.max_nights
  into
    v_price,
    v_max_guests,
    v_included_guests,
    v_extra_price,
    v_min_nights,
    v_max_nights
  from public.lodging_details ld
  join public.businesses b
    on b.id = ld.business_id
  where ld.business_id = p_business_id
    and b.business_type = 'lodging'
    and b.publication_status = 'published';

  if not found then
    raise exception 'El alojamiento no esta disponible.';
  end if;


  v_nights := p_check_out - p_check_in;

  if v_nights < v_min_nights then
    raise exception
      'Este alojamiento requiere una estadia minima de % noches.',
      v_min_nights;
  end if;

  if v_max_nights is not null and v_nights > v_max_nights then
    raise exception
      'Este alojamiento permite una estadia maxima de % noches.',
      v_max_nights;
  end if;

  if p_guests > v_max_guests then
    raise exception
      'El alojamiento permite un maximo de % huespedes.',
      v_max_guests;
  end if;


  -- Manually blocked dates.
  select count(*)
  into v_blocked
  from public.lodging_calendar lc
  where lc.business_id = p_business_id
    and lc.status = 'blocked'
    and lc.date >= p_check_in
    and lc.date < p_check_out;

  if v_blocked > 0 then
    raise exception
      'Una o mas noches seleccionadas no estan disponibles.';
  end if;


  -- Already accepted reservations.
  select count(*)
  into v_conflicts
  from public.lodging_bookings lb
  where lb.business_id = p_business_id
    and lb.status = 'accepted'
    and lb.check_in < p_check_out
    and lb.check_out > p_check_in;

  if v_conflicts > 0 then
    raise exception
      'Las fechas seleccionadas ya fueron reservadas.';
  end if;


  -- Sum each night so calendar price overrides are respected.
  select coalesce(
    sum(
      coalesce(
        lc.price_override,
        v_price
      )
    ),
    0
  )::integer
  into v_base
  from generate_series(
    p_check_in,
    p_check_out - 1,
    interval '1 day'
  ) as d(day)
  left join public.lodging_calendar lc
    on lc.business_id = p_business_id
   and lc.date = d.day::date;


  v_extra :=
    greatest(
      p_guests - v_included_guests,
      0
    )
    * v_extra_price
    * v_nights;

  v_total := v_base + v_extra;


  select
    coalesce(
      nullif(
        trim(
          coalesce(
            u.raw_user_meta_data ->> 'full_name',
            u.raw_user_meta_data ->> 'name',
            ''
          )
        ),
        ''
      ),
      split_part(
        coalesce(u.email, 'Huesped'),
        '@',
        1
      ),
      'Huesped'
    ),
    u.email
  into
    v_name,
    v_email
  from auth.users u
  where u.id = v_user_id;


  insert into public.lodging_bookings (
    business_id,
    guest_user_id,
    guest_name,
    guest_email,
    check_in,
    check_out,
    guests,
    nights,
    base_amount,
    extra_guest_amount,
    total_amount,
    status,
    guest_message
  )
  values (
    p_business_id,
    v_user_id,
    coalesce(v_name, 'Huesped'),
    v_email,
    p_check_in,
    p_check_out,
    p_guests,
    v_nights,
    v_base,
    v_extra,
    v_total,
    'pending',
    nullif(trim(p_message), '')
  )
  returning id
  into v_booking_id;


  return v_booking_id;

end;
$$;


revoke all
on function public.create_lodging_booking(
  uuid,
  date,
  date,
  integer,
  text
)
from public;

grant execute
on function public.create_lodging_booking(
  uuid,
  date,
  date,
  integer,
  text
)
to authenticated;

-- ============================================================
-- END
-- ============================================================
