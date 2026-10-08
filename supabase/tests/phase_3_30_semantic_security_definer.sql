-- Final semantic security contracts; run after all migrations.
do $$
declare
  v_bad_paths integer;
  v_anon_truncate integer;
  v_auth_truncate integer;
  v_bad_helpers integer;
  v_admin_anon integer;
  v_public_helpers integer;
begin
  select count(*) into v_bad_paths
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
      where c like 'search_path=%');
  if v_bad_paths <> 0 then raise exception 'SECURITY DEFINER missing search_path: %', v_bad_paths; end if;

  select count(*) into v_anon_truncate from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
    and has_table_privilege('anon',c.oid,'TRUNCATE');
  select count(*) into v_auth_truncate from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind in ('r','p')
    and has_table_privilege('authenticated',c.oid,'TRUNCATE');
  if v_anon_truncate <> 0 or v_auth_truncate <> 0 then
    raise exception 'TRUNCATE API grants remain anon %, authenticated %', v_anon_truncate, v_auth_truncate;
  end if;

  select count(*) into v_bad_helpers
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
    and p.proname = any(array['context_chat_participants','request_is_visible_to_business',
      'notify_business_managers','record_business_review_event','sync_context_conversation_members'])
    and (has_function_privilege('anon',p.oid,'EXECUTE')
      or has_function_privilege('authenticated',p.oid,'EXECUTE'));
  if v_bad_helpers <> 0 then raise exception 'internal helpers API executable: %',v_bad_helpers; end if;

  select count(*) into v_public_helpers
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace,
       lateral aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  where n.nspname='public' and p.prosecdef and a.grantee=0 and a.privilege_type='EXECUTE'
    and p.proname = any(array['context_chat_participants','request_is_visible_to_business',
      'notify_business_managers','record_business_review_event','sync_context_conversation_members']);
  if v_public_helpers <> 0 then raise exception 'internal helpers retain PUBLIC EXECUTE: %',v_public_helpers; end if;

  select count(*) into v_admin_anon from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef and p.proname like 'admin_%'
    and has_function_privilege('anon',p.oid,'EXECUTE');
  if v_admin_anon <> 0 then raise exception 'admin SECURITY DEFINER callable by anon: %',v_admin_anon; end if;
end;
$$;

-- Exercise the real JWT subject and authenticated database role. Existing
-- provider identity must not cross the global gate.
begin;
select set_config('request.jwt.claim.sub', (select id::text from public.profiles where role='provider' and account_status='active' limit 1), true);
select set_config('request.jwt.claims', jsonb_build_object('sub',(select id::text from public.profiles where role='provider' and account_status='active' limit 1),'role','authenticated','is_anonymous',false)::text, true);
set local role authenticated;
do $$
begin
  if public.current_user_is_admin() then raise exception 'provider acquired global gate'; end if;
  begin
    perform public.admin_analytics_summary();
    raise exception 'provider invoked global admin RPC' using errcode = 'ZX001';
  exception when insufficient_privilege or raise_exception then null;
  end;
end;
$$;
rollback;

select 'phase 3.30 semantic SECURITY DEFINER contracts passed' as result;
