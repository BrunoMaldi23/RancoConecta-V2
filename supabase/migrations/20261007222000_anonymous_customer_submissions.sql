-- Anonymous customer requests and bookings.  Visitors submit through the
-- server-only Edge Function/RPC path; API roles never receive table write/read
-- access to the newly submitted customer data.

create table if not exists public.public_submission_controls (
  identity_hash text primary key check (identity_hash ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0)
);
create table if not exists public.public_submission_dedup (
  fingerprint text primary key check (fingerprint ~ '^[0-9a-f]{64}$'),
  idempotency_key uuid not null unique,
  expires_at timestamptz not null
);
create index if not exists public_submission_controls_window_idx
  on public.public_submission_controls(window_started_at);
create index if not exists public_submission_dedup_expires_idx
  on public.public_submission_dedup(expires_at);

create or replace function public.is_valid_chilean_phone(p_phone text)
returns boolean language sql immutable set search_path=pg_catalog as $$
  select case
    when length(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))=9
      then regexp_replace(coalesce(p_phone,''),'[^0-9]','','g') ~ '^[2-9][0-9]{8}$'
    when length(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))=11
      then regexp_replace(coalesce(p_phone,''),'[^0-9]','','g') ~ '^56[2-9][0-9]{8}$'
    else false end;
$$;

create or replace function public.normalize_chilean_phone(p_phone text)
returns text language sql immutable set search_path=pg_catalog as $$
  select case when length(d)=9 then '+56'||d else '+'||d end
  from (select regexp_replace(coalesce(p_phone,''),'[^0-9]','','g') d) p;
$$;
revoke all on function public.is_valid_chilean_phone(text) from public,anon,authenticated,service_role;
revoke all on function public.normalize_chilean_phone(text) from public,anon,authenticated,service_role;
alter table public.public_submission_controls enable row level security;
alter table public.public_submission_dedup enable row level security;
revoke all on public.public_submission_controls, public.public_submission_dedup
  from public, anon, authenticated, service_role;

alter table public.service_requests alter column customer_id drop not null;
alter table public.service_requests
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists consented_at timestamptz,
  add column if not exists consent_version text,
  add column if not exists submission_fingerprint text;
create index if not exists service_requests_business_created_idx
  on public.service_requests(business_id, created_at desc);

alter table public.gastronomy_table_reservations alter column user_id drop not null;
alter table public.gastronomy_table_reservations
  add column if not exists customer_name text,
  add column if not exists customer_phone text,
  add column if not exists consented_at timestamptz,
  add column if not exists consent_version text,
  add column if not exists submission_fingerprint text;
alter table public.gastronomy_table_reservations
  drop constraint if exists gastronomy_table_reservations_user_id_fkey;
alter table public.gastronomy_table_reservations
  add constraint gastronomy_table_reservations_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete set null;
create unique index if not exists gastronomy_table_reservations_fingerprint_uidx
  on public.gastronomy_table_reservations(submission_fingerprint)
  where submission_fingerprint is not null;

alter table public.lodging_bookings alter column guest_user_id drop not null;
alter table public.lodging_bookings
  add column if not exists guest_phone text,
  add column if not exists consented_at timestamptz,
  add column if not exists consent_version text,
  add column if not exists submission_fingerprint text;
alter table public.lodging_bookings
  drop constraint if exists lodging_bookings_guest_user_id_fkey;
alter table public.lodging_bookings
  add constraint lodging_bookings_guest_user_id_fkey
  foreign key (guest_user_id) references auth.users(id) on delete set null;
create unique index if not exists lodging_bookings_fingerprint_uidx
  on public.lodging_bookings(submission_fingerprint)
  where submission_fingerprint is not null;

create or replace function public.claim_public_submission(
  p_idempotency_key uuid, p_fingerprint text, p_phone_hash text,
  p_ip_hash text
) returns text language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_hash text;
  v_count integer;
  v_started timestamptz;
begin
  if p_idempotency_key is null
     or p_fingerprint !~ '^[0-9a-f]{64}$'
     or p_phone_hash !~ '^[0-9a-f]{64}$'
     or (p_ip_hash is not null and p_ip_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'INVALID_SUBMISSION_CONTROL' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(k,0))
    from (select distinct k from unnest(array[
      'dedup:'||p_fingerprint, 'key:'||p_idempotency_key::text,
      'identity:'||p_phone_hash,
      case when p_ip_hash is null then null else 'identity:'||p_ip_hash end
    ]) k where k is not null order by k) locks;
  if exists(select 1 from public.public_submission_dedup
    where fingerprint=p_fingerprint and expires_at>now()) then return 'duplicate'; end if;
  if exists(select 1 from public.public_submission_dedup
    where idempotency_key=p_idempotency_key and expires_at>now()) then return 'duplicate'; end if;

  with expired as (
    select ctid from public.public_submission_controls
    where window_started_at < now()-interval '24 hours'
    order by window_started_at limit 500 for update skip locked
  ) delete from public.public_submission_controls c using expired e where c.ctid=e.ctid;
  with expired as (
    select ctid from public.public_submission_dedup where expires_at<now()
    order by expires_at limit 500 for update skip locked
  ) delete from public.public_submission_dedup d using expired e where d.ctid=e.ctid;

  for v_hash in select distinct h from unnest(array[p_phone_hash,p_ip_hash]) h
    where h is not null order by h loop
    select request_count,window_started_at into v_count,v_started
      from public.public_submission_controls where identity_hash=v_hash;
    if found and v_started>now()-interval '1 hour'
      and v_count >= (case when v_hash=p_phone_hash then 3 else 10 end) then
      return 'rate_limited';
    end if;
  end loop;
  for v_hash in select distinct h from unnest(array[p_phone_hash,p_ip_hash]) h
    where h is not null order by h loop
    insert into public.public_submission_controls(identity_hash,window_started_at,request_count)
      values(v_hash,now(),1)
      on conflict(identity_hash) do update set
        window_started_at=case when public.public_submission_controls.window_started_at <= now()-interval '1 hour' then now() else public.public_submission_controls.window_started_at end,
        request_count=case when public.public_submission_controls.window_started_at <= now()-interval '1 hour' then 1 else public.public_submission_controls.request_count+1 end;
  end loop;
  insert into public.public_submission_dedup(fingerprint,idempotency_key,expires_at)
    values(p_fingerprint,p_idempotency_key,now()+interval '10 minutes');
  return 'claimed';
end;
$$;

create or replace function public.submit_public_service_request(
  p_business_id uuid, p_category_id uuid, p_subcategory_id uuid,
  p_location_id uuid, p_description text, p_address_text text,
  p_urgency text, p_desired_date date, p_customer_name text,
  p_customer_phone text, p_consent_version text, p_idempotency_key uuid,
  p_fingerprint text, p_phone_hash text, p_ip_hash text
) returns jsonb language plpgsql security definer
set search_path = pg_catalog
as $$
declare v_status text; v_row public.service_requests%rowtype;
begin
  if length(btrim(coalesce(p_customer_name,''))) not between 2 and 100
     or not public.is_valid_chilean_phone(p_customer_phone)
     or length(btrim(coalesce(p_description,''))) not between 12 and 4000
     or p_consent_version is null or length(p_consent_version)>40
     or p_urgency not in ('low','normal','high','urgent')
     or (p_desired_date is not null and p_desired_date<current_date) then
    raise exception 'INVALID_REQUEST' using errcode='22023';
  end if;
  if not exists(select 1 from public.businesses b where b.id=p_business_id
      and b.publication_status::text='published'
      and b.primary_category_id=p_category_id) then
    raise exception 'BUSINESS_OR_CATEGORY_NOT_FOUND' using errcode='P0002';
  end if;
  if not exists(select 1 from public.business_services bs
      join public.subcategories s on s.id=bs.subcategory_id
      where bs.business_id=p_business_id and bs.subcategory_id=p_subcategory_id
        and bs.active and s.category_id=p_category_id) then
    raise exception 'SERVICE_NOT_FOUND' using errcode='P0002';
  end if;
  if p_location_id is not null and not exists(select 1 from public.business_coverage bc
      join public.locations l on l.id=bc.location_id and l.active
      where bc.business_id=p_business_id and bc.location_id=p_location_id) then
    raise exception 'LOCATION_NOT_FOUND' using errcode='P0002';
  end if;
  v_status:=public.claim_public_submission(p_idempotency_key,p_fingerprint,p_phone_hash,p_ip_hash);
  if v_status<>'claimed' then return jsonb_build_object('status',v_status); end if;
  insert into public.service_requests(customer_id,business_id,category_id,subcategory_id,
    location_id,description,address_text,urgency,desired_date,status,customer_name,
    customer_phone,consented_at,consent_version,submission_fingerprint)
  values(null,p_business_id,p_category_id,p_subcategory_id,p_location_id,
    btrim(p_description),nullif(btrim(p_address_text),''),p_urgency::public.request_urgency,
    p_desired_date,'submitted',regexp_replace(btrim(p_customer_name),'\s+',' ','g'),
    public.normalize_chilean_phone(p_customer_phone),now(),p_consent_version,p_fingerprint)
  returning * into v_row;
  return jsonb_build_object('status','created','id',v_row.id,'public_code',v_row.public_code);
end;
$$;

create or replace function public.submit_public_table_reservation(
  p_business_id uuid,p_date date,p_time time,p_guests integer,p_message text,
  p_name text,p_phone text,p_consent_version text,p_idempotency_key uuid,
  p_fingerprint text,p_phone_hash text,p_ip_hash text
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_status text; v_id uuid;
begin
  if length(btrim(coalesce(p_name,''))) not between 2 and 100
    or not public.is_valid_chilean_phone(p_phone)
    or p_date<current_date or p_guests not between 1 and 20
    or (p_message is not null and length(p_message)>1000)
    or p_consent_version is null then
    raise exception 'INVALID_RESERVATION' using errcode='22023';
  end if;
  if not exists(select 1 from public.businesses b where b.id=p_business_id
    and b.business_type::text='gastronomy' and b.publication_status::text='published') then
    raise exception 'BUSINESS_NOT_FOUND' using errcode='P0002';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||p_date::text||p_time::text,0));
  v_status:=public.claim_public_submission(p_idempotency_key,p_fingerprint,p_phone_hash,p_ip_hash);
  if v_status<>'claimed' then return jsonb_build_object('status',v_status); end if;
  insert into public.gastronomy_table_reservations(business_id,user_id,reservation_date,
    reservation_time,guests,message,status,customer_name,customer_phone,consented_at,
    consent_version,submission_fingerprint)
  values(p_business_id,null,p_date,p_time,p_guests,nullif(btrim(p_message),''),'pending',
    regexp_replace(btrim(p_name),'\s+',' ','g'),public.normalize_chilean_phone(p_phone),
    now(),p_consent_version,p_fingerprint) returning id into v_id;
  return jsonb_build_object('status','created','id',v_id);
end; $$;

-- Lodging must retain its existing pricing/availability semantics. The anon
-- RPC duplicates the validated transaction under a business/date lock.
create or replace function public.submit_public_lodging_booking(
  p_business_id uuid,p_check_in date,p_check_out date,p_guests integer,p_message text,
  p_name text,p_phone text,p_consent_version text,p_idempotency_key uuid,
  p_fingerprint text,p_phone_hash text,p_ip_hash text
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
declare v_status text; v_id uuid; v_price integer; v_max integer; v_included integer;
  v_extra_price integer; v_min integer; v_nights integer; v_base integer; v_extra integer;
begin
  if length(btrim(coalesce(p_name,''))) not between 2 and 100
    or not public.is_valid_chilean_phone(p_phone)
    or p_check_in<current_date or p_check_out<=p_check_in or p_guests<1
    or (p_message is not null and length(p_message)>2000) or p_consent_version is null then
    raise exception 'INVALID_RESERVATION' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_business_id::text,0));
  select ld.price_per_night,ld.max_guests,ld.included_guests,ld.extra_guest_price,ld.min_nights
  into v_price,v_max,v_included,v_extra_price,v_min
  from public.lodging_details ld join public.businesses b on b.id=ld.business_id
  where ld.business_id=p_business_id and b.business_type::text='lodging'
    and b.publication_status::text='published';
  if not found then raise exception 'BUSINESS_NOT_FOUND' using errcode='P0002'; end if;
  v_nights:=p_check_out-p_check_in;
  if v_nights<v_min or p_guests>v_max then raise exception 'INVALID_RESERVATION' using errcode='22023'; end if;
  if exists(select 1 from public.lodging_calendar lc where lc.business_id=p_business_id
    and lc.status='blocked' and lc.date>=p_check_in and lc.date<p_check_out)
    or exists(select 1 from public.lodging_bookings lb where lb.business_id=p_business_id
      and lb.status='accepted' and lb.check_in<p_check_out and lb.check_out>p_check_in) then
    raise exception 'DATES_UNAVAILABLE' using errcode='23P01';
  end if;
  select coalesce(sum(coalesce(lc.price_override,v_price)),0)::integer into v_base
  from generate_series(p_check_in,p_check_out-1,interval '1 day') d(day)
  left join public.lodging_calendar lc on lc.business_id=p_business_id and lc.date=d.day::date;
  v_extra:=greatest(p_guests-v_included,0)*v_extra_price*v_nights;
  v_status:=public.claim_public_submission(p_idempotency_key,p_fingerprint,p_phone_hash,p_ip_hash);
  if v_status<>'claimed' then return jsonb_build_object('status',v_status); end if;
  insert into public.lodging_bookings(business_id,guest_user_id,guest_name,guest_email,
    guest_phone,check_in,check_out,guests,nights,base_amount,extra_guest_amount,total_amount,
    status,guest_message,consented_at,consent_version,submission_fingerprint)
  values(p_business_id,null,regexp_replace(btrim(p_name),'\s+',' ','g'),null,
    public.normalize_chilean_phone(p_phone),p_check_in,p_check_out,p_guests,v_nights,
    v_base,v_extra,v_base+v_extra,'pending',nullif(btrim(p_message),''),now(),
    p_consent_version,p_fingerprint) returning id into v_id;
  return jsonb_build_object('status','created','id',v_id);
end; $$;

-- The existing lodging acceptance path checked conflicts without serializing
-- different pending bookings. Lock each business inventory before rechecking
-- availability, so two concurrent provider approvals cannot double-book.
create or replace function public.accept_lodging_booking(p_booking_id uuid)
returns void language plpgsql security definer
set search_path=pg_catalog,public,auth as $$
declare v_business_id uuid; v_booking public.lodging_bookings%rowtype;
  v_conflict integer; v_day date;
begin
  select lb.business_id into v_business_id from public.lodging_bookings lb
  where lb.id=p_booking_id;
  if not found then raise exception 'booking not found' using errcode='P0002'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_business_id::text,0));

  select lb.* into v_booking from public.lodging_bookings lb
  join public.businesses b on b.id=lb.business_id
  where lb.id=p_booking_id and b.owner_id=auth.uid()
  for update of lb;
  if not found then raise exception 'not authorized' using errcode='42501'; end if;
  if v_booking.status<>'pending' then
    raise exception 'booking already processed' using errcode='23514';
  end if;
  select count(*) into v_conflict from public.lodging_bookings lb
  where lb.business_id=v_booking.business_id and lb.id<>v_booking.id
    and lb.status='accepted' and lb.check_in<v_booking.check_out
    and lb.check_out>v_booking.check_in;
  if v_conflict>0 then raise exception 'dates already occupied' using errcode='23P01'; end if;
  select count(*) into v_conflict from public.lodging_calendar lc
  where lc.business_id=v_booking.business_id and lc.status='blocked'
    and lc.date>=v_booking.check_in and lc.date<v_booking.check_out;
  if v_conflict>0 then raise exception 'dates are blocked' using errcode='23P01'; end if;
  update public.lodging_bookings set status='accepted' where id=v_booking.id;
  v_day:=v_booking.check_in;
  while v_day<v_booking.check_out loop
    insert into public.lodging_calendar(business_id,date,status,note)
      values(v_booking.business_id,v_day,'blocked','Reserva confirmada')
      on conflict(business_id,date) do update set status='blocked',note='Reserva confirmada';
    v_day:=v_day+1;
  end loop;
end; $$;

revoke all on function public.claim_public_submission(uuid,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.submit_public_service_request(uuid,uuid,uuid,uuid,text,text,text,date,text,text,text,uuid,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.submit_public_table_reservation(uuid,date,time,integer,text,text,text,text,uuid,text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.submit_public_lodging_booking(uuid,date,date,integer,text,text,text,text,uuid,text,text,text) from public,anon,authenticated,service_role;
grant execute on function public.claim_public_submission(uuid,text,text,text) to service_role;
grant execute on function public.submit_public_service_request(uuid,uuid,uuid,uuid,text,text,text,date,text,text,text,uuid,text,text,text) to service_role;
grant execute on function public.submit_public_table_reservation(uuid,date,time,integer,text,text,text,text,uuid,text,text,text) to service_role;
grant execute on function public.submit_public_lodging_booking(uuid,date,date,integer,text,text,text,text,uuid,text,text,text) to service_role;
revoke execute on function public.create_gastronomy_table_reservation(uuid,date,time,integer,text)
  from public,anon,authenticated;
revoke execute on function public.create_lodging_booking(uuid,date,date,integer,text)
  from public,anon,authenticated;

-- Keep anonymous visitors out of all private request/reservation reads/writes.
revoke all on public.service_requests,public.gastronomy_table_reservations,public.lodging_bookings from public,anon;
revoke all on public.service_requests,public.gastronomy_table_reservations,public.lodging_bookings from authenticated;
grant select on public.service_requests,public.gastronomy_table_reservations,public.lodging_bookings to authenticated;

-- No notifications aimed at nonexistent guest profiles.
create or replace function public.notify_service_request_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.business_id is null then return new; end if;
  if tg_op='INSERT' and new.status='submitted' then
    perform public.notify_business_managers(new.business_id,'service_request_created','Nueva solicitud','Tu negocio recibió una solicitud.');
  elsif tg_op='UPDATE' and old.status is distinct from new.status
    and new.status in ('accepted','rejected') and new.customer_id is not null then
    insert into public.notifications(user_id,type,title,body,entity_type,entity_id,deep_link)
    values(new.customer_id,'service_request_'||new.status::text,'Solicitud actualizada','Cambió el estado de tu solicitud.','service_request',new.id,'/requests/'||new.id::text);
  end if;
  return new;
end; $$;

create or replace function public.notify_table_reservation_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    perform public.notify_business_managers(new.business_id,'new_table_reservation',
      'Nueva reserva de mesa','Tu restaurante recibió una reserva.');
  elsif old.status is distinct from new.status and new.user_id is not null
    and new.status in ('confirmed','rejected') then
    insert into public.notifications(user_id,type,title,body,entity_type,entity_id,deep_link)
    values(new.user_id,'table_reservation_'||new.status,'Reserva actualizada',
      'Cambió el estado de tu reserva.','table_reservation',new.id,
      '/requests/gastronomy/'||new.id::text);
  end if;
  return new;
end; $$;

create or replace function public.notify_lodging_booking_activity()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    perform public.notify_business_managers(new.business_id,'new_lodging_booking',
      'Nueva reserva','Tu alojamiento recibió una reserva.');
  elsif old.status is distinct from new.status and new.guest_user_id is not null
    and new.status in ('accepted','rejected') then
    insert into public.notifications(user_id,type,title,body,entity_type,entity_id,deep_link)
    values(new.guest_user_id,'lodging_booking_'||new.status,'Reserva actualizada',
      'Cambió el estado de tu reserva.','lodging_booking',new.id,
      '/requests/lodging/'||new.id::text);
  end if;
  return new;
end; $$;

create or replace function public.provider_request_contacts(p_business_id uuid)
returns table(request_id uuid,guest_name text,guest_phone text)
language plpgsql security definer set search_path=public,auth as $$
begin
  if auth.uid() is null or not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized' using errcode='42501';
  end if;
  return query
  select sr.id,coalesce(sr.customer_name,p.full_name),coalesce(sr.customer_phone,p.phone)
  from public.service_requests sr
  left join public.profiles p on p.id=sr.customer_id
  where sr.business_id=p_business_id
    and public.request_is_visible_to_business(sr.id,p_business_id);
end; $$;
revoke all on function public.provider_request_contacts(uuid) from public,anon;
grant execute on function public.provider_request_contacts(uuid) to authenticated;

comment on column public.service_requests.customer_id is 'Deprecated nullable identity for historical account-based requests; new visitor requests leave it NULL.';
comment on column public.gastronomy_table_reservations.user_id is 'Deprecated nullable Auth identity; anonymous reservations store customer contact fields.';
comment on column public.lodging_bookings.guest_user_id is 'Deprecated nullable Auth identity; anonymous bookings store guest contact fields.';
