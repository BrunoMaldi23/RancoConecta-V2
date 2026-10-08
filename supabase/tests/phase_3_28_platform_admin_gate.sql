-- Run after the complete migration sequence. Read-only authorization contract.
begin;

do $$
declare
  v_admin_anon integer;
  v_helper_exec integer;
  v_missing_path integer;
begin
  if to_regclass('public.super_admin_sessions') is null then
    raise exception 'super_admin_sessions is missing';
  end if;

  if has_function_privilege('anon',
       'public.current_user_is_admin()', 'EXECUTE') then
    raise exception 'anon can execute current_user_is_admin';
  end if;
  if not has_function_privilege('authenticated',
       'public.current_user_is_admin()', 'EXECUTE') then
    raise exception 'authenticated cannot evaluate the session gate';
  end if;

  select count(*) into v_admin_anon
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and p.proname = any (array[
      'admin_analytics_summary', 'admin_business_review_detail',
      'admin_business_review_queue', 'admin_business_review_stats',
      'admin_get_business_review', 'admin_list_users', 'admin_publish_business',
      'admin_reject_business', 'admin_request_business_changes',
      'admin_restore_business', 'admin_suspend_business',
      'admin_update_whatsapp_settings', 'admin_mark_user_deleted',
      'admin_set_contact_message_status'
    ]::text[])
    and has_function_privilege('anon', p.oid, 'EXECUTE');
  if v_admin_anon <> 0 then
    raise exception 'anon can execute % global admin RPCs', v_admin_anon;
  end if;

  select count(*) into v_helper_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and p.proname = any (array[
      'notify_business_managers', 'record_business_review_event',
      'sync_context_conversation_members'
    ]::text[])
    and (has_function_privilege('anon', p.oid, 'EXECUTE')
      or has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  if v_helper_exec <> 0 then
    raise exception 'internal helper(s) are executable by API roles: %', v_helper_exec;
  end if;

  select count(*) into v_missing_path
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
      where c like 'search_path=%');
  if v_missing_path <> 0 then
    raise exception '% SECURITY DEFINER functions lack an explicit search_path', v_missing_path;
  end if;

  if not has_table_privilege('anon', 'public.businesses', 'SELECT') then
    raise exception 'public Home read was unexpectedly removed';
  end if;
end;
$$;

rollback;
select 'phase 3.28 platform admin gate contracts passed' as result;
