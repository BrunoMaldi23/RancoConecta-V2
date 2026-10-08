-- Run only against local Supabase: psql -v ON_ERROR_STOP=1 -f ...
-- Synthetic identities and records are rolled back.
begin;

insert into auth.users (id, email, is_anonymous) values
  ('00000000-0000-4000-8000-000000031731', 'activity-a@example.test', false),
  ('00000000-0000-4000-8000-000000031732', 'activity-b@example.test', false),
  ('00000000-0000-4000-8000-000000031733', 'activity-provider-a@example.test', false),
  ('00000000-0000-4000-8000-000000031734', 'activity-provider-b@example.test', false),
  ('00000000-0000-4000-8000-000000031735', null, true);

update public.profiles set role = 'provider', account_status = 'active'
where id in ('00000000-0000-4000-8000-000000031733',
             '00000000-0000-4000-8000-000000031734');

insert into public.businesses
  (id, owner_id, business_type, name, slug, publication_status, primary_category_id)
values
  ('00000000-0000-4000-8000-000000031741', '00000000-0000-4000-8000-000000031733',
   'service', 'Activity service A', 'activity-service-a', 'published',
   (select category_id from public.subcategories limit 1)),
  ('00000000-0000-4000-8000-000000031742', '00000000-0000-4000-8000-000000031733',
   'lodging', 'Activity lodging A', 'activity-lodging-a', 'published', null),
  ('00000000-0000-4000-8000-000000031743', '00000000-0000-4000-8000-000000031733',
   'gastronomy', 'Activity table A', 'activity-table-a', 'published', null),
  ('00000000-0000-4000-8000-000000031744', '00000000-0000-4000-8000-000000031734',
   'service', 'Activity service B', 'activity-service-b', 'published',
   (select category_id from public.subcategories limit 1));

insert into public.business_members (business_id, user_id, role) values
  ('00000000-0000-4000-8000-000000031741', '00000000-0000-4000-8000-000000031733', 'owner'),
  ('00000000-0000-4000-8000-000000031742', '00000000-0000-4000-8000-000000031733', 'owner'),
  ('00000000-0000-4000-8000-000000031743', '00000000-0000-4000-8000-000000031733', 'owner'),
  ('00000000-0000-4000-8000-000000031744', '00000000-0000-4000-8000-000000031734', 'owner');

insert into public.service_requests
  (id, customer_id, business_id, category_id, subcategory_id, description, status)
select '00000000-0000-4000-8000-000000031751',
  '00000000-0000-4000-8000-000000031731',
  '00000000-0000-4000-8000-000000031741', category_id, id,
  'Activity service request A', 'submitted'
from public.subcategories limit 1;

insert into public.service_requests
  (id, customer_id, business_id, category_id, subcategory_id, description, status)
select '00000000-0000-4000-8000-000000031752',
  '00000000-0000-4000-8000-000000031732',
  '00000000-0000-4000-8000-000000031744', category_id, id,
  'Activity service request B', 'submitted'
from public.subcategories limit 1;

insert into public.service_requests
  (id, customer_id, business_id, category_id, subcategory_id, description, status)
select '00000000-0000-4000-8000-000000031753',
  '00000000-0000-4000-8000-000000031735',
  '00000000-0000-4000-8000-000000031741', category_id, id,
  'Activity anonymous request', 'submitted'
from public.subcategories limit 1;

insert into public.lodging_bookings
  (id, business_id, guest_user_id, guest_name, check_in, check_out, guests, nights,
   base_amount, total_amount)
values ('00000000-0000-4000-8000-000000031761',
  '00000000-0000-4000-8000-000000031742',
  '00000000-0000-4000-8000-000000031731', 'Fixture',
  '2026-11-01', '2026-11-03', 2, 2, 10000, 10000);

insert into public.gastronomy_table_reservations
  (id, business_id, user_id, reservation_date, reservation_time, guests)
values ('00000000-0000-4000-8000-000000031771',
  '00000000-0000-4000-8000-000000031743',
  '00000000-0000-4000-8000-000000031731',
  '2026-11-01', '20:00', 2);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031731', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000031731","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if (select count(*) from public.service_requests where id in
    ('00000000-0000-4000-8000-000000031751','00000000-0000-4000-8000-000000031752')) <> 1
    or (select count(*) from public.lodging_bookings where id = '00000000-0000-4000-8000-000000031761') <> 1
    or (select count(*) from public.gastronomy_table_reservations where id = '00000000-0000-4000-8000-000000031771') <> 1 then
    raise exception 'customer A activity visibility failed';
  end if;
  begin
    insert into public.service_requests
      (customer_id, business_id, category_id, subcategory_id, description, status)
    select '00000000-0000-4000-8000-000000031732',
      '00000000-0000-4000-8000-000000031741', category_id, id,
      'Spoofed owner request', 'submitted'
    from public.subcategories limit 1;
    raise exception 'spoofed customer_id accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031732', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000031732","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031752') <> 1
    or (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031751') <> 0
    or (select count(*) from public.lodging_bookings where id = '00000000-0000-4000-8000-000000031761') <> 0
    or (select count(*) from public.gastronomy_table_reservations where id = '00000000-0000-4000-8000-000000031771') <> 0 then
    raise exception 'customer B can read A activity';
  end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031733', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000031733","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031751') <> 1
    or (select count(*) from public.lodging_bookings where id = '00000000-0000-4000-8000-000000031761') <> 1
    or (select count(*) from public.gastronomy_table_reservations where id = '00000000-0000-4000-8000-000000031771') <> 1
    or (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031752') <> 0 then
    raise exception 'provider A visibility failed';
  end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031734', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000031734","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031751') <> 0
    or (select count(*) from public.lodging_bookings where id = '00000000-0000-4000-8000-000000031761') <> 0
    or (select count(*) from public.gastronomy_table_reservations where id = '00000000-0000-4000-8000-000000031771') <> 0 then
    raise exception 'provider B can read A activity';
  end if;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031735', true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-000000031735","role":"authenticated","is_anonymous":true}', true);
do $$ begin
  if (select count(*) from public.service_requests where id = '00000000-0000-4000-8000-000000031753') <> 1 then
    raise exception 'anonymous owner cannot read own request';
  end if;
end $$;
reset role;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  begin
    if (select count(*) from public.service_requests
        where id = '00000000-0000-4000-8000-000000031753') <> 0 then
      raise exception 'unauthenticated user can read anonymous request';
    end if;
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

rollback;
select 'phase 3.17.3 RLS checks passed' as result;
