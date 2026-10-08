-- Run against local Supabase with psql -v ON_ERROR_STOP=1 -f this file.
-- Every fixture and mutation is rolled back.
begin;

insert into auth.users (id, email, is_anonymous)
values
  ('00000000-0000-4000-8000-000000031701', 'phase317-admin@example.test', false),
  ('00000000-0000-4000-8000-000000031702', 'phase317-provider@example.test', false),
  ('00000000-0000-4000-8000-000000031703', 'phase317-customer@example.test', false),
  ('00000000-0000-4000-8000-000000031704', null, true),
  ('00000000-0000-4000-8000-000000031705', null, false);

insert into public.profiles (id, full_name, role, account_status)
values
  ('00000000-0000-4000-8000-000000031701', 'Phase Admin', 'super_admin', 'active'),
  ('00000000-0000-4000-8000-000000031702', 'Phase Provider', 'provider', 'active'),
  ('00000000-0000-4000-8000-000000031703', 'Phase Customer', 'customer', 'active'),
  ('00000000-0000-4000-8000-000000031704', 'Phase Visitor', 'customer', 'active'),
  ('00000000-0000-4000-8000-000000031705', 'Phase No Email', 'customer', 'active')
on conflict (id) do update set full_name = excluded.full_name,
  role = excluded.role, account_status = excluded.account_status;
insert into public.super_admin_sessions(user_id,purpose,expires_at) values
 ('00000000-0000-4000-8000-000000031701','Phase 3.17 contract admin session',now()+interval '50 minutes');

insert into auth.users (id, email, is_anonymous)
select gen_random_uuid(), 'phase317-row-' || g || '@example.test', false
from generate_series(1, 53) g;

update public.profiles set account_status = 'active',
  full_name = 'Phase Row ' || split_part(u.email, '-', 3)
from auth.users u
where profiles.id = u.id and u.email like 'phase317-row-%@example.test';

insert into public.businesses (owner_id, business_type, name, slug, publication_status)
select '00000000-0000-4000-8000-000000031702', 'service',
  'Phase Business ' || g, 'phase-business-' || g, 'published'
from generate_series(1, 23) g;
insert into public.businesses (owner_id, business_type, name, slug, publication_status)
values ('00000000-0000-4000-8000-000000031702', 'lodging',
  'Phase Lodging', 'phase-lodging', 'suspended');
insert into public.business_members (business_id, user_id)
select id, '00000000-0000-4000-8000-000000031702'
from public.businesses where slug = 'phase-business-1';
insert into public.business_members (business_id, user_id)
select id, '00000000-0000-4000-8000-000000031703'
from public.businesses where slug = 'phase-business-2';

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031701', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000031701","role":"authenticated","is_anonymous":false}', true);

do $$
declare c public.categories; result jsonb;
begin
  if not public.is_admin() then raise exception 'admin not recognized'; end if;
  if (select count(*) from public.business_members) < 2 then
    raise exception 'admin cannot read memberships';
  end if;
  c := public.admin_upsert_category(null, 'Phase Category', 'phase-category', true);
  if c.name <> 'Phase Category' or not c.active then
    raise exception 'category create failed';
  end if;
  c := public.admin_upsert_category(c.id, 'Phase Edited', 'phase-category', false);
  if c.name <> 'Phase Edited' or c.active then
    raise exception 'category edit/deactivate failed';
  end if;
  c := public.admin_upsert_category(c.id, c.name, c.slug, true);
  if not c.active then raise exception 'category reactivate failed'; end if;
  if not exists (select 1 from public.admin_list_categories() x where x.id = c.id) then
    raise exception 'admin cannot list category';
  end if;
  begin
    perform public.admin_upsert_category(null, 'Duplicate', 'phase-category', true);
    raise exception 'duplicate slug accepted';
  exception when unique_violation then
    if sqlerrm not like '%CATEGORY_SLUG_DUPLICATE%' then raise; end if;
  end;
  begin
    perform public.admin_upsert_category(null, ' ', 'phase-empty', true);
    raise exception 'empty name accepted';
  exception when invalid_parameter_value then
    if sqlerrm not like '%CATEGORY_NAME_INVALID%' then raise; end if;
  end;
  begin
    perform public.admin_upsert_category(null, 'Bad Slug', 'Bad Slug', true);
    raise exception 'bad slug accepted';
  exception when invalid_parameter_value then
    if sqlerrm not like '%CATEGORY_SLUG_INVALID%' then raise; end if;
  end;

  result := public.admin_search_users(1, 10, null, null);
  if jsonb_array_length(result->'rows') <> 10 or (result->>'total_count')::int < 58 then
    raise exception 'user page 1/total failed: %', result;
  end if;
  result := public.admin_search_users(2, 20, null, null);
  if jsonb_array_length(result->'rows') <> 20 then raise exception 'user page 2 failed'; end if;
  result := public.admin_search_users(1, 50, null, null);
  if jsonb_array_length(result->'rows') <> 50 then raise exception 'user page 50 failed'; end if;
  result := public.admin_search_users(1, 10, 'Phase Provider', 'PROVIDER');
  if (result->>'total_count')::int <> 1 then raise exception 'search + role failed'; end if;
  result := public.admin_search_users(1, 10, ' Phase Provider ', 'PROVIDER');
  if (result->>'total_count')::int <> 1 then raise exception 'search trim failed'; end if;
  result := public.admin_search_users(1, 10, 'Phase Customer', 'CUSTOMER');
  if (result->>'total_count')::int <> 1 then raise exception 'customer role failed'; end if;
  result := public.admin_search_users(1, 10, 'Phase Admin', 'ADMIN');
  if (result->>'total_count')::int <> 1 then raise exception 'super_admin role failed'; end if;
  begin
    perform public.admin_search_users(null, 10, null, null);
    raise exception 'null page accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(0, 10, null, null);
    raise exception 'zero page accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(-1, 10, null, null);
    raise exception 'negative page accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(10001, 10, null, null);
    raise exception 'extreme page accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(1, 0, null, null);
    raise exception 'zero page size accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(1, -10, null, null);
    raise exception 'negative page size accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(1, 100000, null, null);
    raise exception 'oversized page accepted';
  exception when invalid_parameter_value then null; end;
  begin
    perform public.admin_search_users(1, 10, repeat('x', 101), null);
    raise exception 'long search accepted';
  exception when invalid_parameter_value then null; end;
  result := public.admin_search_users(1, 10, 'never-a-real-person-317', null);
  if (result->>'total_count')::int <> 0 or jsonb_array_length(result->'rows') <> 0 then
    raise exception 'empty page total failed';
  end if;
  result := public.admin_search_users(1, 10, 'Phase Visitor', 'VISITOR');
  if (result->>'total_count')::int <> 1 or
    (result->'rows'->0->>'is_anonymous')::boolean is not true then
    raise exception 'visitor signal failed';
  end if;
  result := public.admin_search_users(1, 10, 'Phase No Email', 'VISITOR');
  if (result->>'total_count')::int <> 0 then
    raise exception 'missing email mislabeled visitor';
  end if;
  result := public.admin_search_business_reviews(
    'published', 'service', 'Phase Business', 10, 20);
  if jsonb_array_length(result->'rows') <> 3 or
    (result->>'total_count')::int <> 23 then
    raise exception 'business final page/total failed: %', result;
  end if;
  result := public.admin_search_business_reviews(
    'published', 'service', 'Phase Business', 10, 30);
  if jsonb_array_length(result->'rows') <> 0 or
    (result->>'total_count')::int <> 23 then
    raise exception 'business empty last page total failed: %', result;
  end if;
  result := public.admin_search_business_reviews(
    'suspended', 'lodging', 'Phase Lodging', 10, 0);
  if (result->>'total_count')::int <> 1 then
    raise exception 'business status/type/search failed';
  end if;
end;
$$;

-- The in-use fixture is added by the privileged test connection.
reset role;
insert into public.subcategories (category_id, name, slug, icon_key)
select id, 'Phase Subcategory', 'phase-subcategory', 'category'
from public.categories where slug = 'phase-category';
set local role authenticated;
do $$
declare c_id uuid;
begin
  select id into c_id from public.categories where slug = 'phase-category';
  begin
    perform public.admin_delete_category(c_id);
    raise exception 'in-use category deleted';
  exception when foreign_key_violation then
    if sqlerrm not like '%CATEGORY_IN_USE%' then raise; end if;
  end;
  perform public.admin_upsert_category(c_id, 'Phase Edited', 'phase-category', false);
end;
$$;

reset role;
delete from public.subcategories where slug = 'phase-subcategory';
set local role authenticated;
do $$
declare c_id uuid;
begin
  select id into c_id from public.categories where slug = 'phase-category';
  perform public.admin_delete_category(c_id);
  if exists(select 1 from public.categories where id = c_id) then
    raise exception 'unused category not deleted';
  end if;
end;
$$;

-- Provider, customer, anonymous Auth user and unauthenticated role are denied.
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031702', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000031702","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if public.is_admin() then raise exception 'provider identified as admin'; end if;
  if exists (select 1 from public.business_members where user_id <> auth.uid()) then
    raise exception 'provider sees another membership';
  end if;
  if not exists (select 1 from public.business_members where user_id = auth.uid()) then
    raise exception 'provider cannot see own membership';
  end if;
  begin perform public.admin_upsert_category(null, 'Denied', 'phase-denied', true);
    raise exception 'provider category write allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_users(1, 10, null, null);
    raise exception 'provider directory allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_business_reviews(null, null, null, 10, 0);
    raise exception 'provider business directory allowed';
  exception when insufficient_privilege then null; end;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031703', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000031703","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if public.is_admin() then raise exception 'customer identified as admin'; end if;
  if exists (select 1 from public.business_members where user_id <> auth.uid()) then
    raise exception 'customer sees another membership';
  end if;
  if not exists (select 1 from public.business_members where user_id = auth.uid()) then
    raise exception 'customer cannot see own membership';
  end if;
  begin perform public.admin_delete_category(gen_random_uuid());
    raise exception 'customer category delete allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_users(1, 10, null, null);
    raise exception 'customer directory allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_list_categories();
    raise exception 'customer category list allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_business_reviews(null, null, null, 10, 0);
    raise exception 'customer business directory allowed';
  exception when insufficient_privilege then null; end;
end; $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000031704', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000031704","role":"authenticated","is_anonymous":true}', true);
do $$ begin
  if public.is_admin() then raise exception 'Auth anonymous identified as admin'; end if;
  if (select count(*) from public.business_members) <> 0 then
    raise exception 'Auth anonymous sees memberships';
  end if;
  begin perform public.admin_list_categories();
    raise exception 'anonymous category list allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_users(1, 10, null, null);
    raise exception 'anonymous directory allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_business_reviews(null, null, null, 10, 0);
    raise exception 'anonymous business directory allowed';
  exception when insufficient_privilege then null; end;
end; $$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$ begin
  if public.is_admin() then raise exception 'anon identified as admin'; end if;
  if (select count(*) from public.business_members) <> 0 then
    raise exception 'anon sees memberships';
  end if;
  begin perform public.admin_list_categories();
    raise exception 'anon category RPC allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_users(1, 10, null, null);
    raise exception 'anon directory allowed';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_search_business_reviews(null, null, null, 10, 0);
    raise exception 'anon business directory allowed';
  exception when insufficient_privilege then null; end;
end; $$;

rollback;
select 'phase 3.17 database checks passed' as result;
