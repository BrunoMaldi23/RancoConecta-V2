-- ============================================================
-- RANCO CONECTA V2
-- Commerce/location management RPC
-- ============================================================

create or replace function public.update_manageable_business_location(
  p_business_id uuid,
  p_address_text text,
  p_location_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to manage business';
  end if;

  if p_location_id is not null and not exists (
    select 1
    from public.locations l
    where l.id = p_location_id
      and l.active
  ) then
    raise exception 'invalid location';
  end if;

  update public.businesses
  set address_text = nullif(trim(coalesce(p_address_text, address_text)), '')
  where id = p_business_id;

  if not found then
    raise exception 'business not found';
  end if;

  delete from public.business_coverage
  where business_id = p_business_id;

  if p_location_id is not null then
    insert into public.business_coverage (
      business_id,
      location_id
    )
    values (
      p_business_id,
      p_location_id
    )
    on conflict (business_id, location_id) do nothing;
  end if;
end;
$$;

grant execute on function public.update_manageable_business_location(uuid, text, uuid)
to authenticated;
