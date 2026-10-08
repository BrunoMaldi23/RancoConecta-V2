-- SECURITY DEFINER admin RPCs must not be callable with an anonymous role.
-- Authenticated grants remain intact for the existing server-side role checks.
do $$
declare
  v_function regprocedure;
begin
  for v_function in
    select p.oid::regprocedure
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and left(p.proname, 6) = 'admin_'
      and has_function_privilege('anon', p.oid, 'execute')
  loop
    execute format(
      'revoke execute on function %s from public, anon',
      v_function
    );
  end loop;
end;
$$;
