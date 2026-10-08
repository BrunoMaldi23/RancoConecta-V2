-- Final authorization contract after role/session objects are installed.
-- This migration is intentionally sequenced after 20261005006000, which creates
-- super_admin_sessions and the hardened helper implementation.

do $$
begin
  if to_regclass('public.super_admin_sessions') is null then
    raise exception 'platform admin gate requires public.super_admin_sessions';
  end if;
  if to_regprocedure('public.is_super_admin()') is null
     or to_regprocedure('public.current_user_is_admin()') is null then
    raise exception 'platform admin gate helpers are missing';
  end if;
end;
$$;

create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select public.is_super_admin()
    and exists (
      select 1
      from public.super_admin_sessions s
      where s.user_id = auth.uid()
        and s.ended_at is null
        and s.expires_at > now()
    );
$$;

revoke all on function public.current_user_is_admin()
  from public, anon, authenticated, service_role;
grant execute on function public.current_user_is_admin()
  to authenticated, service_role;

-- Policies still evaluate this legacy alias for anon; it returns false unless
-- the request has a valid, explicit SuperAdmin session.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$ select public.current_user_is_admin(); $$;
revoke all on function public.is_admin()
  from public, anon, authenticated, service_role;
grant execute on function public.is_admin()
  to anon, authenticated, service_role;

-- All admin_* SECURITY DEFINER RPCs are platform-global. Authenticated EXECUTE
-- remains necessary for the console's user JWT; the function bodies enforce
-- current_user_is_admin(), which now requires super_admin + active session.
-- Remove only anonymous/PUBLIC access. Do not alter service_role grants.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as signature
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
        'admin_update_whatsapp_settings',
        'admin_mark_user_deleted',
        'admin_set_contact_message_status'
      ]::text[])
  loop
    execute format('revoke execute on function %s from public, anon', r.signature);
  end loop;
end;
$$;

-- Internal trigger helpers are callable only by their owning trigger/function
-- execution context. The 3.27 migration preserves service_role only when it
-- was previously explicitly/effectively granted; this repeats the exact scope.
do $$
declare
  r record;
  v_service_execute boolean;
begin
  for r in
    select p.oid, p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.prosecdef
      and p.proname = any (array[
        'notify_business_managers',
        'record_business_review_event',
        'sync_context_conversation_members'
      ]::text[])
  loop
    v_service_execute := has_function_privilege('service_role', r.oid, 'EXECUTE');
    execute format(
      'revoke execute on function %s from public, anon, authenticated',
      r.signature
    );
    if v_service_execute then
      execute format('grant execute on function %s to service_role', r.signature);
    end if;
  end loop;
end;
$$;

do $$
declare
  v_helpers integer;
  v_admin_anon integer;
  v_bad_paths integer;
begin
  select count(*) into v_helpers
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and p.proname = any (array[
      'notify_business_managers',
      'record_business_review_event',
      'sync_context_conversation_members'
    ]::text[]);
  if v_helpers <> 3 then
    raise exception 'expected 3 internal SECURITY DEFINER helpers, found %', v_helpers;
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
    raise exception 'admin SECURITY DEFINER RPCs still executable by anon: %', v_admin_anon;
  end if;

  select count(*) into v_bad_paths
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (
      select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
      where c like 'search_path=%'
    );
  if v_bad_paths <> 0 then
    raise exception '% public SECURITY DEFINER functions lack explicit search_path', v_bad_paths;
  end if;
end;
$$;
