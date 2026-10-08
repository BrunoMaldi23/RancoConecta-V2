-- Prevent direct Data API execution of internal SECURITY DEFINER helpers.
-- Parent SECURITY DEFINER functions continue calling them as their owner.
-- The service_role grant is not touched.

do $$
declare
  r record;
  v_service_role_had_execute boolean;
begin
  for r in
    select p.oid, p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and p.prosecdef
      and p.proname in (
        'notify_business_managers',
        'record_business_review_event',
        'sync_context_conversation_members'
      )
  loop
    v_service_role_had_execute := has_function_privilege(
      'service_role', r.oid, 'EXECUTE'
    );
    execute format(
      'revoke execute on function %s from public, anon, authenticated',
      r.signature
    );
    if v_service_role_had_execute then
      execute format('grant execute on function %s to service_role', r.signature);
    end if;
  end loop;

  if (select count(*) from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.prokind = 'f' and p.prosecdef
        and p.proname in (
          'notify_business_managers',
          'record_business_review_event',
          'sync_context_conversation_members'
        )) <> 3 then
    raise exception 'expected all three internal SECURITY DEFINER helpers';
  end if;

  if has_function_privilege('anon',
       'public.notify_business_managers(uuid,text,text,text)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.notify_business_managers(uuid,text,text,text)', 'EXECUTE') then
    raise exception 'notify_business_managers remains directly executable by an API role';
  end if;
  if has_function_privilege('anon',
       'public.record_business_review_event(uuid,text,uuid,text,text,text,jsonb)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.record_business_review_event(uuid,text,uuid,text,text,text,jsonb)', 'EXECUTE') then
    raise exception 'record_business_review_event remains directly executable by an API role';
  end if;
  if has_function_privilege('anon',
       'public.sync_context_conversation_members(uuid)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.sync_context_conversation_members(uuid)', 'EXECUTE') then
    raise exception 'sync_context_conversation_members remains directly executable by an API role';
  end if;
end;
$$;
