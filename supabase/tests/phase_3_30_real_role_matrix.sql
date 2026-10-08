-- Integration checks using existing snapshot identities; all changes roll back.
-- Run via psql so \\gset can hold fixture IDs without displaying them.
begin;
select id as tenant_admin_id from public.profiles where role='admin' and account_status='active' limit 1 \gset
select id as customer_id from public.profiles where role='customer' and account_status='active' limit 1 \gset
select id as provider_id from public.profiles where role='provider' and account_status='active' limit 1 \gset
select owner_id as owner_id from public.businesses where owner_id is not null limit 1 \gset
select id as owner_business_id from public.businesses where owner_id = :'owner_id' limit 1 \gset
select b.id as other_business_id from public.businesses b
where b.owner_id <> :'owner_id'::uuid
  and not exists (select 1 from public.business_members bm
    where bm.business_id=b.id and bm.user_id=:'owner_id'::uuid
      and bm.status='active' and bm.role in ('owner','manager'))
limit 1 \gset
select set_config('ranco.test.owner_business', :'owner_business_id', true);
select set_config('ranco.test.other_business', :'other_business_id', true);

select set_config('request.jwt.claim.sub', :'tenant_admin_id', true);
select set_config('request.jwt.claims', jsonb_build_object('sub', :'tenant_admin_id', 'role', 'authenticated', 'is_anonymous', false)::text, true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'tenant admin entered global gate'; end if;
  begin perform public.admin_analytics_summary();
    raise exception 'tenant admin called global RPC' using errcode='ZX001';
  exception when insufficient_privilege or raise_exception then null;
  end;
end $$;
reset role;

select set_config('request.jwt.claim.sub', :'customer_id', true);
select set_config('request.jwt.claims', jsonb_build_object('sub', :'customer_id', 'role', 'authenticated', 'is_anonymous', false)::text, true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'customer entered global gate'; end if;
  if public.is_business_admin(current_setting('ranco.test.owner_business')::uuid) then raise exception 'customer received owner scope'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub', :'provider_id', true);
select set_config('request.jwt.claims', jsonb_build_object('sub', :'provider_id', 'role', 'authenticated', 'is_anonymous', false)::text, true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'provider entered global gate'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub', :'owner_id', true);
select set_config('request.jwt.claims', jsonb_build_object('sub', :'owner_id', 'role', 'authenticated', 'is_anonymous', false)::text, true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'owner entered global gate'; end if;
  if not public.is_business_admin(current_setting('ranco.test.owner_business')::uuid) then raise exception 'owner lost own scope'; end if;
  if public.is_business_admin(current_setting('ranco.test.other_business')::uuid) then raise exception 'owner escaped business scope'; end if;
end $$;
reset role;
rollback;
select 'phase 3.30 real role matrix passed' as result;
