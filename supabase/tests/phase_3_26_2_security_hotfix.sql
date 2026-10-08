-- Postconditions for 20261007160000_emergency_grants_only.sql.
-- Read-only contract; run after applying the grants-only migration.
begin;

do $$
declare
  t record;
  v_admin_anon integer;
  v_admin_authenticated integer;
begin
  for t in
    select c.oid, n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p')
  loop
    if has_table_privilege('anon', t.oid, 'TRUNCATE')
      or has_table_privilege('authenticated', t.oid, 'TRUNCATE') then
      raise exception 'API role retains TRUNCATE on %.%', t.nspname, t.relname;
    end if;
  end loop;

  select count(*) into v_admin_anon
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
  if v_admin_anon <> 0 then
    raise exception '% targeted admin SECURITY DEFINER RPCs executable by anon', v_admin_anon;
  end if;

  select count(*) into v_admin_authenticated
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
    and has_function_privilege('authenticated', p.oid, 'EXECUTE');
  if v_admin_authenticated <> 12 then
    raise exception 'expected authenticated EXECUTE on all 12 admin RPCs, found %', v_admin_authenticated;
  end if;

  if not has_table_privilege('anon', 'public.businesses', 'SELECT')
    or not has_table_privilege('authenticated', 'public.businesses', 'SELECT') then
    raise exception 'businesses SELECT access was unexpectedly removed';
  end if;
end;
$$;

rollback;
select 'phase 3.26.2A grants-only contracts passed' as result;
