-- Pin every application SECURITY DEFINER function to trusted schemas and put
-- pg_temp last, preventing caller-created temporary objects from shadowing
-- unqualified relations/types inside privileged functions.
do $$
declare
  r record;
  v_bad_schema_grants integer;
begin
  if to_regnamespace('public') is null
     or to_regnamespace('auth') is null
     or to_regnamespace('storage') is null then
    raise exception 'trusted SECURITY DEFINER schemas are missing';
  end if;

  select count(*) into v_bad_schema_grants
  from (values ('anon'), ('authenticated'), ('service_role')) api_role(role_name)
  where has_schema_privilege(api_role.role_name, 'public', 'CREATE')
     or has_schema_privilege(api_role.role_name, 'auth', 'CREATE')
     or has_schema_privilege(api_role.role_name, 'storage', 'CREATE');
  if v_bad_schema_grants <> 0 then
    raise exception 'untrusted API role can CREATE in a trusted search_path schema';
  end if;

  for r in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
  loop
    execute format(
      'alter function %s set search_path = pg_catalog, public, auth, storage, pg_temp',
      r.signature
    );
  end loop;
end;
$$;

do $$
declare v_unsafe integer;
begin
  select count(*) into v_unsafe
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosecdef
    and not exists (
      select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
      where c = 'search_path=pg_catalog, public, auth, storage, pg_temp'
    );
  if v_unsafe <> 0 then
    raise exception '% public SECURITY DEFINER functions retain an unsafe search_path', v_unsafe;
  end if;
end;
$$;
