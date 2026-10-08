-- Internal authorization helpers expose cross-tenant relationship signals.
-- Their SECURITY DEFINER callers execute as the function owner and remain
-- functional; application roles must use the scoped wrapper RPCs instead.
revoke execute on function public.context_chat_participants(text, uuid)
  from public, anon, authenticated;
revoke execute on function public.request_is_visible_to_business(uuid, uuid)
  from public, anon, authenticated;

do $$
begin
  if has_function_privilege(
    'anon', 'public.context_chat_participants(text,uuid)', 'EXECUTE'
  ) or has_function_privilege(
    'authenticated', 'public.context_chat_participants(text,uuid)', 'EXECUTE'
  ) then
    raise exception 'context_chat_participants remains API executable';
  end if;
  if has_function_privilege(
    'anon', 'public.request_is_visible_to_business(uuid,uuid)', 'EXECUTE'
  ) or has_function_privilege(
    'authenticated', 'public.request_is_visible_to_business(uuid,uuid)', 'EXECUTE'
  ) then
    raise exception 'request_is_visible_to_business remains API executable';
  end if;
  if not has_function_privilege(
    'service_role', 'public.context_chat_participants(text,uuid)', 'EXECUTE'
  ) or not has_function_privilege(
    'service_role', 'public.request_is_visible_to_business(uuid,uuid)', 'EXECUTE'
  ) then
    raise exception 'internal helper backend execution was unexpectedly removed';
  end if;
end;
$$;
