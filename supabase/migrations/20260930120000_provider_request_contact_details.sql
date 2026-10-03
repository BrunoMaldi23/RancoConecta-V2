-- Contact details are exposed only to active managers of the addressed business.
-- Service requests and profiles remain unchanged.
create or replace function public.provider_request_contacts(p_business_id uuid)
returns table (
  request_id uuid,
  guest_name text,
  guest_phone text
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized';
  end if;

  return query
  select sr.id, p.full_name, p.phone
  from public.service_requests sr
  join public.profiles p on p.id = sr.customer_id
  where sr.business_id = p_business_id
    and public.request_is_visible_to_business(sr.id, p_business_id);
end;
$$;

revoke all on function public.provider_request_contacts(uuid) from public, anon;
grant execute on function public.provider_request_contacts(uuid) to authenticated;
