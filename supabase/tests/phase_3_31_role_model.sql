-- Contract assertions; run against a clean restored snapshot after migrations.
do $$
declare
  v_count bigint;
  v_def text;
begin
  if not exists (
    select 1 from public.profiles
    where id = 'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid
      and role = 'admin' and account_status = 'active'
  ) then raise exception 'confirmed global admin missing'; end if;

  select count(*) into v_count from public.profiles
  where role in ('customer', 'super_admin');
  if v_count <> 0 then raise exception 'deprecated product roles remain: %', v_count; end if;

  select count(*) into v_count from public.profiles
  where role = 'legacy_customer' and account_status = 'active';
  if v_count <> 0 then raise exception 'active legacy customer profile remains: %', v_count; end if;

  if not has_function_privilege('authenticated',
      'public.current_user_is_admin()', 'EXECUTE') then
    raise exception 'authenticated is missing admin gate execution';
  end if;
  if has_function_privilege('anon',
      'public.current_user_is_admin()', 'EXECUTE') then
    raise exception 'anon can execute admin gate';
  end if;

  v_def := pg_get_functiondef('public.current_user_is_admin()'::regprocedure);
  if v_def ilike '%super_admin_sessions%' or v_def ilike '%is_super_admin%' then
    raise exception 'current_user_is_admin retains obsolete gate dependency';
  end if;
  if v_def not ilike '%admin%' or v_def not ilike '%active%' then
    raise exception 'current_user_is_admin lacks role/status checks';
  end if;

  if has_function_privilege('authenticated',
      'public.start_super_admin_session(text,integer)', 'EXECUTE')
     or has_function_privilege('authenticated',
      'public.end_super_admin_session()', 'EXECUTE') then
    raise exception 'obsolete global-session RPC remains executable';
  end if;

  if has_function_privilege('authenticated',
      'public.create_direct_service_request(uuid,uuid,uuid,text,text,text,date,uuid)',
      'EXECUTE') then
    raise exception 'legacy customer request RPC remains executable';
  end if;

  if exists (select 1 from pg_policies
      where schemaname = 'public' and tablename = 'service_requests'
        and policyname in ('service_requests_customer_insert',
          'service_requests_participants_read', 'service_requests_participants_update',
          'account session allowed')) then
    raise exception 'customer request policies remain';
  end if;

  if not exists (select 1 from pg_constraint
      where conrelid = 'public.profiles'::regclass
        and conname = 'profiles_role_check'
        and pg_get_constraintdef(oid) ilike '%legacy_customer%') then
    raise exception 'profile role constraint does not preserve archived history';
  end if;
end;
$$;

-- The last active administrator cannot demote itself even through its RPC.
begin;
select set_config('request.jwt.claim.sub',
  'a7affb25-ad32-4836-be38-cb2af81343c7', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
set local role authenticated;
do $$
begin
  begin
    perform public.admin_change_user_role(
      'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid, 'provider');
    raise exception 'last admin demotion unexpectedly succeeded';
  exception when check_violation then
    if sqlerrm not like '%LAST_ADMIN%' then raise; end if;
  end;
end;
$$;
rollback;
