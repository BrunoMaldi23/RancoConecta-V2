-- Grants-only production hotfix for the currently audited public objects.
-- Removes only TRUNCATE from anon/authenticated and EXECUTE from anon/PUBLIC
-- on the explicitly identified administrative SECURITY DEFINER RPCs.
-- Does not alter data, functions, policies, default privileges, or other roles.

revoke truncate on all tables in schema public from anon, authenticated;

do $$
declare
  r record;
begin
  for r in
    select p.oid, p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.prosecdef
      and p.proname = any (array[
        'admin_analytics_summary',
        'admin_business_review_detail',
        'admin_business_review_queue',
        'admin_business_review_stats',
        'admin_get_business_review',
        'admin_list_users',
        'admin_publish_business',
        'admin_reject_business',
        'admin_request_business_changes',
        'admin_restore_business',
        'admin_suspend_business',
        'admin_update_whatsapp_settings'
      ]::text[])
      and has_function_privilege('anon', p.oid, 'EXECUTE')
  loop
    execute format('revoke execute on function %s from anon', r.signature);

    if exists (
      select 1
      from pg_proc p
      cross join lateral aclexplode(coalesce(
        p.proacl,
        acldefault('f', p.proowner)
      )) acl
      where p.oid = r.oid
        and acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) then
      execute format('revoke execute on function %s from public', r.signature);
    end if;
  end loop;
end;
$$;

do $$
declare
  v_anon_truncate integer;
  v_authenticated_truncate integer;
  v_admin_anon_execute integer;
begin
  select count(*) into v_anon_truncate
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and has_table_privilege('anon', c.oid, 'TRUNCATE');

  select count(*) into v_authenticated_truncate
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relkind in ('r', 'p')
    and has_table_privilege('authenticated', c.oid, 'TRUNCATE');

  select count(*) into v_admin_anon_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind = 'f'
    and p.prosecdef
    and p.proname = any (array[
      'admin_analytics_summary',
      'admin_business_review_detail',
      'admin_business_review_queue',
      'admin_business_review_stats',
      'admin_get_business_review',
      'admin_list_users',
      'admin_publish_business',
      'admin_reject_business',
      'admin_request_business_changes',
      'admin_restore_business',
      'admin_suspend_business',
      'admin_update_whatsapp_settings'
    ]::text[])
    and has_function_privilege('anon', p.oid, 'EXECUTE');

  if v_anon_truncate <> 0
    or v_authenticated_truncate <> 0
    or v_admin_anon_execute <> 0 then
    raise exception 'grants-only hotfix postcondition failed: truncate anon %, truncate authenticated %, admin anon execute %',
      v_anon_truncate, v_authenticated_truncate, v_admin_anon_execute;
  end if;
end;
$$;
