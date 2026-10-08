-- Run against an isolated production snapshot after the exact pending replay.
-- All inserted rows and rate-control buckets are rolled back.
begin;
do $$
declare
  v_business uuid;
  v_category uuid;
  v_subcategory uuid;
  v_request jsonb;
  v_duplicate jsonb;
  v_table jsonb;
  v_lodging jsonb;
  v_profiles bigint;
  v_auth bigint;
  v_phone_hash text := repeat('a',64);
  v_ip_hash text := repeat('b',64);
  v_key uuid := '132e4567-e89b-42d3-a456-426614174000';
  v_fp text := repeat('c',64);
  v_date date;
  v_lodging_id uuid;
  v_attempt integer;
  v_lodging_accept_def text;
begin
  if has_table_privilege('anon','public.service_requests','SELECT')
    or has_table_privilege('anon','public.service_requests','INSERT')
    or has_table_privilege('anon','public.gastronomy_table_reservations','SELECT')
    or has_table_privilege('anon','public.gastronomy_table_reservations','INSERT')
    or has_table_privilege('anon','public.lodging_bookings','SELECT')
    or has_table_privilege('anon','public.lodging_bookings','INSERT') then
    raise exception 'anonymous direct request/reservation table access exists';
  end if;
  if has_table_privilege('authenticated','public.service_requests','INSERT')
    or has_table_privilege('authenticated','public.service_requests','UPDATE')
    or has_table_privilege('authenticated','public.service_requests','DELETE')
    or has_table_privilege('authenticated','public.gastronomy_table_reservations','INSERT')
    or has_table_privilege('authenticated','public.lodging_bookings','INSERT') then
    raise exception 'authenticated direct request/reservation write exists';
  end if;
  if has_table_privilege('anon','public.service_requests','TRUNCATE')
    or has_table_privilege('authenticated','public.service_requests','TRUNCATE')
    or has_table_privilege('anon','public.lodging_bookings','TRUNCATE')
    or has_table_privilege('authenticated','public.gastronomy_table_reservations','TRUNCATE') then
    raise exception 'dangerous truncate privilege returned';
  end if;
  if has_function_privilege('anon','public.submit_public_service_request(uuid,uuid,uuid,uuid,text,text,text,date,text,text,text,uuid,text,text,text)','EXECUTE')
    or has_function_privilege('anon','public.submit_public_table_reservation(uuid,date,time,integer,text,text,text,text,uuid,text,text,text)','EXECUTE')
    or has_function_privilege('anon','public.submit_public_lodging_booking(uuid,date,date,integer,text,text,text,text,uuid,text,text,text)','EXECUTE') then
    raise exception 'anonymous can call privileged submission RPC directly';
  end if;
  v_lodging_accept_def:=pg_get_functiondef('public.accept_lodging_booking(uuid)'::regprocedure);
  if v_lodging_accept_def not ilike '%pg_advisory_xact_lock%' then
    raise exception 'lodging acceptance does not serialize inventory conflict checks';
  end if;

  select count(*) into v_profiles from public.profiles;
  select count(*) into v_auth from auth.users;
  -- Production snapshot has published listings with primary_category_id NULL;
  -- use the existing service->subcategory category evidence only inside this
  -- rollback-only fixture so the request endpoint can be exercised end-to-end.
  update public.businesses b set primary_category_id=s.category_id
  from (select b0.id,sc.category_id from public.businesses b0
    join public.business_services bs on bs.business_id=b0.id and bs.active
    join public.subcategories sc on sc.id=bs.subcategory_id
    where b0.publication_status::text='published' and sc.category_id is not null
    order by b0.id limit 1) s
  where b.id=s.id;
  select b.id,b.primary_category_id,bs.subcategory_id
    into v_business,v_category,v_subcategory
  from public.businesses b join public.business_services bs on bs.business_id=b.id and bs.active
  where b.publication_status::text='published' and b.primary_category_id is not null
  order by b.id limit 1;
  if v_business is null then raise exception 'snapshot lacks a published business service fixture'; end if;

  v_request:=public.submit_public_service_request(v_business,v_category,v_subcategory,null,
    'Prueba aislada de solicitud anónima','', 'normal',null,'Cliente QA 332','+56912345678',
    'privacy-2026-10-01',v_key,v_fp,v_phone_hash,v_ip_hash);
  if v_request->>'status'<>'created' then raise exception 'anonymous request was not created'; end if;
  if not exists(select 1 from public.service_requests where id=(v_request->>'id')::uuid
       and customer_id is null and customer_name='Cliente QA 332'
       and customer_phone='+56912345678' and status::text='submitted'
       and consented_at is not null and consent_version='privacy-2026-10-01') then
    raise exception 'request fields/status/consent contract failed';
  end if;
  v_duplicate:=public.submit_public_service_request(v_business,v_category,v_subcategory,null,
    'Prueba aislada de solicitud anónima','', 'normal',null,'Cliente QA 332','+56912345678',
    'privacy-2026-10-01',v_key,v_fp,v_phone_hash,v_ip_hash);
  if v_duplicate->>'status'<>'duplicate' then raise exception 'duplicate request was accepted'; end if;
  v_duplicate:=public.submit_public_service_request(v_business,v_category,v_subcategory,null,
    'Contenido distinto para probar llave repetida','', 'normal',null,'Cliente QA 332','+56912345678',
    'privacy-2026-10-01',v_key,repeat('f',64),v_phone_hash,v_ip_hash);
  if v_duplicate->>'status'<>'duplicate' then raise exception 'idempotency key reuse was accepted'; end if;
  for v_attempt in 1..3 loop
    v_duplicate:=public.submit_public_service_request(v_business,v_category,v_subcategory,null,
      'Otra prueba aislada de solicitud anónima '||v_attempt,'','normal',null,
      'Cliente QA 332','+56912345678','privacy-2026-10-01',
      gen_random_uuid(),md5(v_attempt::text)||md5('extra-'||v_attempt::text),v_phone_hash,v_ip_hash);
  end loop;
  if v_duplicate->>'status'<>'rate_limited' then raise exception 'request rate limit did not activate'; end if;
  update public.public_submission_controls set window_started_at=now()-interval '2 hours'
  where identity_hash in (v_phone_hash,v_ip_hash);
  v_duplicate:=public.submit_public_service_request(v_business,v_category,v_subcategory,null,
    'Solicitud después de la ventana de rate limit','', 'normal',null,'Cliente QA 332','+56912345678',
    'privacy-2026-10-01',gen_random_uuid(),repeat('9',64),v_phone_hash,v_ip_hash);
  if v_duplicate->>'status'<>'created' then raise exception 'rate limit did not reset after its window'; end if;

  select id into v_business from public.businesses
  where business_type::text='gastronomy' and publication_status::text='published' limit 1;
  if v_business is not null then
    v_table:=public.submit_public_table_reservation(v_business,current_date+1,'20:00',2,
      'QA temporal','Cliente QA 332','+56912345678','privacy-2026-10-01',gen_random_uuid(),
      md5('table'||clock_timestamp()::text)||md5('table2'||clock_timestamp()::text),
      repeat('d',64),null);
    if v_table->>'status'<>'created' then raise exception 'anonymous table reservation failed'; end if;
    if not exists(select 1 from public.gastronomy_table_reservations
      where id=(v_table->>'id')::uuid and user_id is null and customer_name='Cliente QA 332'
        and customer_phone='+56912345678' and consented_at is not null) then
      raise exception 'table reservation anonymous fields failed';
    end if;
  end if;

  select id into v_business from public.businesses
  where business_type::text='lodging' and publication_status::text='published' limit 1;
  if v_business is not null then
    for v_attempt in 1..180 loop
      v_date:=current_date+v_attempt;
      begin
        v_lodging:=public.submit_public_lodging_booking(v_business,v_date,v_date+2,1,
          'QA temporal','Cliente QA 332','+56912345678','privacy-2026-10-01',gen_random_uuid(),
          md5('lodging'||v_attempt::text)||md5('stay'||v_attempt::text),repeat('e',64),null);
        exit;
      exception when exclusion_violation then null;
      end;
    end loop;
    if v_lodging is null or v_lodging->>'status'<>'created' then
      raise exception 'no available date range for isolated lodging flow test';
    end if;
    select (v_lodging->>'id')::uuid into v_lodging_id;
    if not exists(select 1 from public.lodging_bookings where id=v_lodging_id
      and guest_user_id is null and guest_name='Cliente QA 332'
      and guest_phone='+56912345678' and consented_at is not null) then
      raise exception 'lodging anonymous fields failed';
    end if;
  end if;
  if (select count(*) from public.profiles)<>v_profiles
     or (select count(*) from auth.users)<>v_auth then
    raise exception 'anonymous submission created a profile or Auth identity';
  end if;
end;
$$;
rollback;
