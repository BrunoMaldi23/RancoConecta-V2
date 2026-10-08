-- Legacy businesses may have owner_id without an active business_members row.
-- Use both ownership sources and deduplicate recipients.
create or replace function public.notify_business_managers(
  p_business_id uuid, p_type text, p_title text, p_body text
)
returns void
language sql security definer
set search_path = public
as $$
  insert into public.notifications (
    user_id, type, title, body, entity_type, entity_id
  )
  select recipient.user_id, p_type, p_title, p_body, 'business', p_business_id
  from (
    select b.owner_id as user_id from public.businesses b
    where b.id = p_business_id
    union
    select bm.user_id from public.business_members bm
    where bm.business_id = p_business_id
      and bm.status = 'active' and bm.role in ('owner', 'manager')
  ) recipient
  join public.profiles p on p.id = recipient.user_id
  where p.account_status = 'active';
$$;

create or replace function public.notify_service_request_activity()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  v_new_submission boolean := false;
begin
  if new.business_id is null then return new; end if;
  if tg_op = 'INSERT' then
    v_new_submission := new.status = 'submitted';
  else
    v_new_submission := old.status is distinct from new.status
      and new.status = 'submitted';
  end if;
  if v_new_submission then
    insert into public.notifications (
      user_id, type, title, body, entity_type, entity_id, deep_link
    )
    select b.owner_id, 'service_request_created', 'Nueva solicitud',
      'Tu negocio recibió una solicitud.', 'service_request', new.id,
      '/provider/requests'
    from public.businesses b
    where b.id = new.business_id
      and not exists (
        select 1 from public.business_members bm
        where bm.business_id = b.id and bm.user_id = b.owner_id
          and bm.status = 'active' and bm.role in ('owner', 'manager')
      );
  elsif tg_op = 'UPDATE' then
    if old.status is distinct from new.status
       and new.status in ('accepted', 'rejected') then
      insert into public.notifications (
        user_id, type, title, body, entity_type, entity_id, deep_link
      ) values (
        new.customer_id, 'service_request_' || new.status::text,
        'Solicitud actualizada', 'Cambió el estado de tu solicitud.',
        'service_request', new.id, '/requests/' || new.id::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists notify_service_request_activity on public.service_requests;
create trigger notify_service_request_activity
after insert or update of status on public.service_requests
for each row execute function public.notify_service_request_activity();

create or replace function public.notify_lodging_booking_activity()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (
      user_id, type, title, body, entity_type, entity_id, deep_link
    )
    select recipient.user_id, 'new_lodging_booking', 'Nueva reserva',
      'Tu alojamiento recibió una reserva.', 'lodging_booking', new.id,
      '/provider/bookings'
    from (
      select b.owner_id as user_id from public.businesses b
      where b.id = new.business_id
      union
      select bm.user_id from public.business_members bm
      where bm.business_id = new.business_id and bm.status = 'active'
        and bm.role in ('owner', 'manager')
    ) recipient;
  elsif old.status is distinct from new.status
      and new.status in ('accepted', 'rejected') then
    insert into public.notifications (
      user_id, type, title, body, entity_type, entity_id, deep_link
    ) values (
      new.guest_user_id, 'lodging_booking_' || new.status,
      'Reserva actualizada', 'Cambió el estado de tu reserva.',
      'lodging_booking', new.id, '/requests/lodging/' || new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_lodging_booking_activity on public.lodging_bookings;
create trigger notify_lodging_booking_activity
after insert or update of status on public.lodging_bookings
for each row execute function public.notify_lodging_booking_activity();

create or replace function public.notify_table_reservation_activity()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (
      user_id, type, title, body, entity_type, entity_id, deep_link
    )
    select recipient.user_id, 'new_table_reservation', 'Nueva reserva de mesa',
      'Tu restaurante recibió una reserva.', 'table_reservation', new.id,
      '/provider/table-reservations'
    from (
      select b.owner_id as user_id from public.businesses b
      where b.id = new.business_id
      union
      select bm.user_id from public.business_members bm
      where bm.business_id = new.business_id and bm.status = 'active'
        and bm.role in ('owner', 'manager')
    ) recipient;
  elsif old.status is distinct from new.status
      and new.status in ('confirmed', 'rejected') then
    insert into public.notifications (
      user_id, type, title, body, entity_type, entity_id, deep_link
    ) values (
      new.user_id, 'table_reservation_' || new.status,
      'Reserva actualizada', 'Cambió el estado de tu reserva de mesa.',
      'table_reservation', new.id, '/requests/gastronomy/' || new.id::text
    );
  end if;
  return new;
end;
$$;

drop trigger if exists notify_table_reservation_activity
on public.gastronomy_table_reservations;
create trigger notify_table_reservation_activity
after insert or update of status on public.gastronomy_table_reservations
for each row execute function public.notify_table_reservation_activity();
