-- ============================================================
-- RANCO CONECTA V2
-- Lodging / bookings / calendar production backend
-- ============================================================

create extension if not exists pgcrypto;

-- ============================================================
-- 1. LODGING DETAILS
-- ============================================================

create table if not exists public.lodging_details (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  price_per_night integer not null default 0,
  max_guests integer not null default 2,
  included_guests integer not null default 2,
  extra_guest_price integer not null default 0,
  bedrooms integer not null default 1,
  beds integer not null default 1,
  bathrooms numeric(4,1) not null default 1,
  check_in_time time not null default '15:00',
  check_out_time time not null default '11:00',
  min_nights integer not null default 1,
  cancellation_policy text,
  house_rules text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.lodging_details
  add column if not exists price_per_night integer not null default 0,
  add column if not exists max_guests integer not null default 2,
  add column if not exists included_guests integer not null default 2,
  add column if not exists extra_guest_price integer not null default 0,
  add column if not exists bedrooms integer not null default 1,
  add column if not exists beds integer not null default 1,
  add column if not exists bathrooms numeric(4,1) not null default 1,
  add column if not exists check_in_time time not null default '15:00',
  add column if not exists check_out_time time not null default '11:00',
  add column if not exists min_nights integer not null default 1,
  add column if not exists cancellation_policy text,
  add column if not exists house_rules text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists lodging_details_business_uidx
  on public.lodging_details(business_id);

alter table public.lodging_details
  drop constraint if exists lodging_details_price_non_negative;

alter table public.lodging_details
  add constraint lodging_details_price_non_negative
  check (price_per_night >= 0);

alter table public.lodging_details
  drop constraint if exists lodging_details_extra_price_non_negative;

alter table public.lodging_details
  add constraint lodging_details_extra_price_non_negative
  check (extra_guest_price >= 0);

alter table public.lodging_details
  drop constraint if exists lodging_details_guests_valid;

alter table public.lodging_details
  add constraint lodging_details_guests_valid
  check (
    max_guests >= 1
    and included_guests >= 1
    and included_guests <= max_guests
  );

alter table public.lodging_details
  drop constraint if exists lodging_details_rooms_valid;

alter table public.lodging_details
  add constraint lodging_details_rooms_valid
  check (
    bedrooms >= 0
    and beds >= 1
    and bathrooms >= 0
    and min_nights >= 1
  );


-- ============================================================
-- 2. LODGING CALENDAR
-- ============================================================

create table if not exists public.lodging_calendar (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  date date not null,
  status text not null default 'available',
  price_override integer,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.lodging_calendar
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists business_id uuid,
  add column if not exists date date,
  add column if not exists status text not null default 'available',
  add column if not exists price_override integer,
  add column if not exists note text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists lodging_calendar_business_date_uidx
  on public.lodging_calendar(business_id, date);

create index if not exists lodging_calendar_range_idx
  on public.lodging_calendar(business_id, date);

alter table public.lodging_calendar
  drop constraint if exists lodging_calendar_status_check;

alter table public.lodging_calendar
  add constraint lodging_calendar_status_check
  check (status in ('available', 'blocked'));

alter table public.lodging_calendar
  drop constraint if exists lodging_calendar_price_check;

alter table public.lodging_calendar
  add constraint lodging_calendar_price_check
  check (price_override is null or price_override >= 0);


-- ============================================================
-- 3. LODGING BOOKINGS
-- ============================================================

create table if not exists public.lodging_bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  guest_user_id uuid not null references auth.users(id) on delete cascade,
  guest_name text not null,
  guest_email text,
  check_in date not null,
  check_out date not null,
  guests integer not null,
  nights integer not null,
  base_amount integer not null default 0,
  extra_guest_amount integer not null default 0,
  total_amount integer not null default 0,
  status text not null default 'pending',
  guest_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.lodging_bookings
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists business_id uuid,
  add column if not exists guest_user_id uuid,
  add column if not exists guest_name text,
  add column if not exists guest_email text,
  add column if not exists check_in date,
  add column if not exists check_out date,
  add column if not exists guests integer,
  add column if not exists nights integer,
  add column if not exists base_amount integer not null default 0,
  add column if not exists extra_guest_amount integer not null default 0,
  add column if not exists total_amount integer not null default 0,
  add column if not exists status text not null default 'pending',
  add column if not exists guest_message text,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create index if not exists lodging_bookings_business_idx
  on public.lodging_bookings(business_id, created_at desc);

create index if not exists lodging_bookings_guest_idx
  on public.lodging_bookings(guest_user_id, created_at desc);

create index if not exists lodging_bookings_dates_idx
  on public.lodging_bookings(business_id, check_in, check_out);

alter table public.lodging_bookings
  drop constraint if exists lodging_bookings_dates_check;

alter table public.lodging_bookings
  add constraint lodging_bookings_dates_check
  check (check_out > check_in);

alter table public.lodging_bookings
  drop constraint if exists lodging_bookings_guests_check;

alter table public.lodging_bookings
  add constraint lodging_bookings_guests_check
  check (guests >= 1);

alter table public.lodging_bookings
  drop constraint if exists lodging_bookings_amounts_check;

alter table public.lodging_bookings
  add constraint lodging_bookings_amounts_check
  check (
    nights >= 1
    and base_amount >= 0
    and extra_guest_amount >= 0
    and total_amount >= 0
  );

alter table public.lodging_bookings
  drop constraint if exists lodging_bookings_status_check;

alter table public.lodging_bookings
  add constraint lodging_bookings_status_check
  check (
    status in (
      'pending',
      'accepted',
      'rejected',
      'cancelled'
    )
  );


-- ============================================================
-- 4. UPDATED_AT
-- ============================================================

drop trigger if exists lodging_details_updated_at
  on public.lodging_details;

create trigger lodging_details_updated_at
before update on public.lodging_details
for each row
execute function public.set_updated_at();


drop trigger if exists lodging_calendar_updated_at
  on public.lodging_calendar;

create trigger lodging_calendar_updated_at
before update on public.lodging_calendar
for each row
execute function public.set_updated_at();


drop trigger if exists lodging_bookings_updated_at
  on public.lodging_bookings;

create trigger lodging_bookings_updated_at
before update on public.lodging_bookings
for each row
execute function public.set_updated_at();


-- ============================================================
-- 5. DEFAULT DETAILS FOR LODGINGS
-- ============================================================

insert into public.lodging_details (
  business_id
)
select b.id
from public.businesses b
where b.business_type = 'lodging'
on conflict (business_id) do nothing;


-- Automatically create details for future lodgings.

create or replace function public.ensure_lodging_details()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin

  if new.business_type = 'lodging' then

    insert into public.lodging_details (
      business_id
    )
    values (
      new.id
    )
    on conflict (business_id) do nothing;

  end if;

  return new;

end;
$$;


drop trigger if exists businesses_create_lodging_details
  on public.businesses;

create trigger businesses_create_lodging_details
after insert or update of business_type
on public.businesses
for each row
execute function public.ensure_lodging_details();


-- ============================================================
-- 6. RLS
-- ============================================================

alter table public.lodging_details enable row level security;
alter table public.lodging_calendar enable row level security;
alter table public.lodging_bookings enable row level security;


-- LODGING DETAILS

drop policy if exists "public read lodging details"
  on public.lodging_details;

create policy "public read lodging details"
on public.lodging_details
for select
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_details.business_id
      and (
        b.publication_status = 'published'
        or b.owner_id = auth.uid()
      )
  )
);


drop policy if exists "owners update lodging details"
  on public.lodging_details;

create policy "owners update lodging details"
on public.lodging_details
for update
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_details.business_id
      and b.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_details.business_id
      and b.owner_id = auth.uid()
  )
);


drop policy if exists "owners insert lodging details"
  on public.lodging_details;

create policy "owners insert lodging details"
on public.lodging_details
for insert
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_details.business_id
      and b.owner_id = auth.uid()
  )
);


-- CALENDAR

drop policy if exists "public read lodging calendar"
  on public.lodging_calendar;

create policy "public read lodging calendar"
on public.lodging_calendar
for select
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_calendar.business_id
      and (
        b.publication_status = 'published'
        or b.owner_id = auth.uid()
      )
  )
);


drop policy if exists "owners insert lodging calendar"
  on public.lodging_calendar;

create policy "owners insert lodging calendar"
on public.lodging_calendar
for insert
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_calendar.business_id
      and b.owner_id = auth.uid()
  )
);


drop policy if exists "owners update lodging calendar"
  on public.lodging_calendar;

create policy "owners update lodging calendar"
on public.lodging_calendar
for update
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_calendar.business_id
      and b.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_calendar.business_id
      and b.owner_id = auth.uid()
  )
);


drop policy if exists "owners delete lodging calendar"
  on public.lodging_calendar;

create policy "owners delete lodging calendar"
on public.lodging_calendar
for delete
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_calendar.business_id
      and b.owner_id = auth.uid()
  )
);


-- BOOKINGS

drop policy if exists "guests read own lodging bookings"
  on public.lodging_bookings;

create policy "guests read own lodging bookings"
on public.lodging_bookings
for select
using (
  guest_user_id = auth.uid()
);


drop policy if exists "owners read lodging bookings"
  on public.lodging_bookings;

create policy "owners read lodging bookings"
on public.lodging_bookings
for select
using (
  exists (
    select 1
    from public.businesses b
    where b.id = lodging_bookings.business_id
      and b.owner_id = auth.uid()
  )
);


-- ============================================================
-- 7. CREATE BOOKING RPC
-- ============================================================

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
    ld.min_nights
  into
    v_price,
    v_max_guests,
    v_included_guests,
    v_extra_price,
    v_min_nights
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
      'La estadia minima para este alojamiento es de % noches.',
      v_min_nights;
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


-- ============================================================
-- 8. ACCEPT BOOKING RPC
-- ============================================================

create or replace function public.accept_lodging_booking(
  p_booking_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.lodging_bookings%rowtype;
  v_conflict integer;
  v_day date;
begin

  select lb.*
  into v_booking
  from public.lodging_bookings lb
  join public.businesses b
    on b.id = lb.business_id
  where lb.id = p_booking_id
    and b.owner_id = auth.uid()
  for update of lb;

  if not found then
    raise exception
      'No tienes permiso para gestionar esta reserva.';
  end if;


  if v_booking.status <> 'pending' then
    raise exception
      'La reserva ya fue procesada.';
  end if;


  -- Another accepted reservation on the same nights.
  select count(*)
  into v_conflict
  from public.lodging_bookings lb
  where lb.business_id = v_booking.business_id
    and lb.id <> v_booking.id
    and lb.status = 'accepted'
    and lb.check_in < v_booking.check_out
    and lb.check_out > v_booking.check_in;

  if v_conflict > 0 then
    raise exception
      'Las fechas ya fueron ocupadas por otra reserva.';
  end if;


  -- A provider may have manually blocked a date after the request.
  select count(*)
  into v_conflict
  from public.lodging_calendar lc
  where lc.business_id = v_booking.business_id
    and lc.status = 'blocked'
    and lc.date >= v_booking.check_in
    and lc.date < v_booking.check_out;

  if v_conflict > 0 then
    raise exception
      'Existen fechas bloqueadas en este periodo.';
  end if;


  update public.lodging_bookings
  set status = 'accepted'
  where id = v_booking.id;


  -- Accepted reservation becomes blocked in the public calendar.
  v_day := v_booking.check_in;

  while v_day < v_booking.check_out loop

    insert into public.lodging_calendar (
      business_id,
      date,
      status,
      note
    )
    values (
      v_booking.business_id,
      v_day,
      'blocked',
      'Reserva confirmada'
    )
    on conflict (business_id, date)
    do update set
      status = 'blocked',
      note = 'Reserva confirmada';

    v_day := v_day + 1;

  end loop;

end;
$$;


-- ============================================================
-- 9. REJECT BOOKING RPC
-- ============================================================

create or replace function public.reject_lodging_booking(
  p_booking_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
  v_status text;
begin

  select
    lb.business_id,
    lb.status
  into
    v_business_id,
    v_status
  from public.lodging_bookings lb
  join public.businesses b
    on b.id = lb.business_id
  where lb.id = p_booking_id
    and b.owner_id = auth.uid()
  for update of lb;

  if not found then
    raise exception
      'No tienes permiso para gestionar esta reserva.';
  end if;

  if v_status <> 'pending' then
    raise exception
      'La reserva ya fue procesada.';
  end if;

  update public.lodging_bookings
  set status = 'rejected'
  where id = p_booking_id;

end;
$$;


-- ============================================================
-- 10. PERMISSIONS FOR RPC
-- ============================================================

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


revoke all
on function public.accept_lodging_booking(uuid)
from public;

grant execute
on function public.accept_lodging_booking(uuid)
to authenticated;


revoke all
on function public.reject_lodging_booking(uuid)
from public;

grant execute
on function public.reject_lodging_booking(uuid)
to authenticated;


-- ============================================================
-- 11. STORAGE - BUSINESS MEDIA
-- ============================================================

insert into storage.buckets (
  id,
  name,
  public
)
values (
  'business-media',
  'business-media',
  true
)
on conflict (id)
do update set
  public = true;


drop policy if exists
  "lodging public business media"
on storage.objects;

create policy
  "lodging public business media"
on storage.objects
for select
using (
  bucket_id = 'business-media'
);


drop policy if exists
  "lodging owners upload business media"
on storage.objects;

create policy
  "lodging owners upload business media"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.businesses b
    where b.owner_id = auth.uid()
      and b.id::text = (storage.foldername(name))[2]
  )
);


drop policy if exists
  "lodging owners update business media"
on storage.objects;

create policy
  "lodging owners update business media"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);


drop policy if exists
  "lodging owners delete business media"
on storage.objects;

create policy
  "lodging owners delete business media"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.businesses b
    where b.owner_id = auth.uid()
      and b.id::text = (storage.foldername(name))[2]
  )
);


-- ============================================================
-- 12. POSTGREST TABLE PRIVILEGES
-- ============================================================

grant select
on public.lodging_details
to anon, authenticated;

grant insert, update, select
on public.lodging_details
to authenticated;


grant select
on public.lodging_calendar
to anon, authenticated;

grant insert, update, delete, select
on public.lodging_calendar
to authenticated;


grant select
on public.lodging_bookings
to authenticated;


-- ============================================================
-- END
-- ============================================================