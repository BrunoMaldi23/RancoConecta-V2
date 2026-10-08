-- Read-only postconditions for 20261007170000_revoke_internal_definer_helpers.sql.
begin;

do $$
begin
  if has_function_privilege('anon',
       'public.notify_business_managers(uuid,text,text,text)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.notify_business_managers(uuid,text,text,text)', 'EXECUTE') then
    raise exception 'notification helper is exposed to API roles';
  end if;
  if has_function_privilege('anon',
       'public.record_business_review_event(uuid,text,uuid,text,text,text,jsonb)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.record_business_review_event(uuid,text,uuid,text,text,text,jsonb)', 'EXECUTE') then
    raise exception 'review audit helper is exposed to API roles';
  end if;
  if has_function_privilege('anon',
       'public.sync_context_conversation_members(uuid)', 'EXECUTE')
    or has_function_privilege('authenticated',
       'public.sync_context_conversation_members(uuid)', 'EXECUTE') then
    raise exception 'conversation membership helper is exposed to API roles';
  end if;
end;
$$;

rollback;
select 'phase 3.27 internal SECURITY DEFINER helper contracts passed' as result;
