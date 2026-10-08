-- Run after 20261007200000; read-only except transaction-local assertions.
begin;
do $$
declare v_unsafe integer;
begin
  select count(*) into v_unsafe
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
    and not exists(select 1 from unnest(coalesce(p.proconfig,array[]::text[])) c
      where c = any(array[
        'search_path=pg_catalog, public, auth, storage, pg_temp',
        'search_path=pg_catalog',
        'search_path=pg_catalog, public, auth',
        'search_path=public',
        'search_path=public, auth'
      ]));
  if v_unsafe <> 0 then
    raise exception '% public SECURITY DEFINER functions have unsafe search_path', v_unsafe;
  end if;

  if has_schema_privilege('anon','public','CREATE')
    or has_schema_privilege('authenticated','public','CREATE')
    or has_schema_privilege('service_role','public','CREATE')
    or has_schema_privilege('anon','auth','CREATE')
    or has_schema_privilege('authenticated','auth','CREATE')
    or has_schema_privilege('service_role','auth','CREATE')
    or has_schema_privilege('anon','storage','CREATE')
    or has_schema_privilege('authenticated','storage','CREATE')
    or has_schema_privilege('service_role','storage','CREATE') then
    raise exception 'untrusted API role can create objects in a SECURITY DEFINER path';
  end if;
end;
$$;
rollback;
select 'phase 3.29 SECURITY DEFINER search_path contracts passed' as result;
