-- Read-only catalog inventory. Body data is reduced to boolean indicators;
-- no function source, table rows, identifiers, or secret values are returned.
with definitions as (
  select p.oid, n.nspname as schema, p.proname as name,
    p.oid::regprocedure::text as signature, owner.rolname as owner,
    coalesce(array_to_string(p.proconfig, ','), '') as search_path,
    has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute,
    has_function_privilege('service_role', p.oid, 'EXECUTE') as service_role_execute,
    exists (
      select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
      where a.grantee = 0 and a.privilege_type = 'EXECUTE'
    ) as public_execute,
    p.prorettype = 'trigger'::regtype as trigger_only,
    exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass
      and d.objid = p.oid and d.deptype = 'e') as extension_member,
    lower(pg_get_functiondef(p.oid)) as body
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  join pg_roles owner on owner.oid = p.proowner
  where p.prosecdef and n.nspname not in ('pg_catalog', 'information_schema')
)
select schema, name, signature, owner, search_path,
  public_execute, anon_execute, authenticated_execute, service_role_execute,
  position('auth.uid' in body) > 0 as auth_uid_marker,
  (body ~ 'current_user_is_admin|is_admin\(\)|is_super_admin|auth\.role\(\)|\.role::text|\.role\s*=') as role_guard_marker,
  (body ~ 'is_business_owner|is_business_admin|user_can_manage_business|owner_id|business_id|tenant') as tenant_scope_marker,
  (body ~ '\m(insert|update|delete|truncate)\s') as has_dml,
  (body ~ '\mexecute\s+(format|[a-z_])') as has_dynamic_sql,
  trigger_only, extension_member,
  case
    when trigger_only or extension_member then 'SAFE'
    when name = 'current_user_is_admin' or name = 'is_admin'
      or name like 'admin_%'
      or name in ('notify_business_managers', 'record_business_review_event',
        'sync_context_conversation_members') then 'NEEDS HARDENING'
    when schema = 'public'
      and search_path <> 'search_path=pg_catalog, public, auth, storage, pg_temp'
      then 'NEEDS HARDENING'
    when (anon_execute or public_execute) and body ~ '\m(insert|update|delete|truncate)\s'
      and body !~ 'auth\.uid|is_admin|is_super_admin|is_business_admin|is_business_owner|user_can_manage_business'
      then 'NEEDS HARDENING'
    when not anon_execute and not public_execute and not authenticated_execute
      then 'SAFE'
    when body ~ 'auth\.uid|is_admin|is_super_admin|is_business_admin|is_business_owner|user_can_manage_business'
      and body !~ '\mexecute\s+(format|[a-z_])' then 'SAFE'
    else 'NEEDS HARDENING'
  end as classification
from definitions
order by schema, name, signature;
