-- ============================================================
-- RANCO CONECTA V2
-- Secure service business management RPCs
-- ============================================================

create or replace function public.update_manageable_business_profile(
  p_business_id uuid,
  p_name text,
  p_description text,
  p_phone text,
  p_whatsapp text,
  p_email text,
  p_website text,
  p_address_text text
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to manage business';
  end if;

  update public.businesses
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    description = nullif(trim(coalesce(p_description, description)), ''),
    phone = nullif(trim(coalesce(p_phone, phone)), ''),
    whatsapp = nullif(trim(coalesce(p_whatsapp, whatsapp)), ''),
    email = nullif(trim(coalesce(p_email, email)), ''),
    website = nullif(trim(coalesce(p_website, website)), ''),
    address_text = nullif(trim(coalesce(p_address_text, address_text)), '')
  where id = p_business_id
  returning * into v_business;

  if not found then
    raise exception 'business not found';
  end if;

  return v_business;
end;
$$;

create or replace function public.replace_manageable_business_services(
  p_business_id uuid,
  p_service_items jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_item jsonb;
  v_subcategory_id uuid;
  v_category_id uuid;
  v_expected_category_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to manage business';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.business_type <> 'service' then
    raise exception 'services management is only available for service businesses';
  end if;

  delete from public.business_services
  where business_id = p_business_id;

  if p_service_items is null or jsonb_array_length(p_service_items) = 0 then
    return;
  end if;

  for v_item in select * from jsonb_array_elements(p_service_items) loop
    v_subcategory_id := (v_item ->> 'subcategory_id')::uuid;

    select s.category_id into v_category_id
    from public.subcategories s
    where s.id = v_subcategory_id
      and s.active;

    if v_category_id is null then
      raise exception 'invalid service';
    end if;

    if v_expected_category_id is null then
      v_expected_category_id := coalesce(v_business.primary_category_id, v_category_id);
    end if;

    if v_category_id <> v_expected_category_id then
      raise exception 'all services must belong to the business category';
    end if;

    insert into public.business_services (
      business_id,
      subcategory_id,
      description,
      price_from,
      active
    )
    values (
      p_business_id,
      v_subcategory_id,
      nullif(trim(v_item ->> 'description'), ''),
      nullif(v_item ->> 'price_from', '')::integer,
      true
    )
    on conflict (business_id, subcategory_id)
    do update set
      description = excluded.description,
      price_from = excluded.price_from,
      active = true,
      updated_at = now();
  end loop;

  update public.businesses
  set primary_category_id = v_expected_category_id
  where id = p_business_id
    and primary_category_id is null;
end;
$$;

create or replace function public.replace_manageable_business_coverage(
  p_business_id uuid,
  p_location_ids uuid[]
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

  delete from public.business_coverage
  where business_id = p_business_id;

  if p_location_ids is null then
    return;
  end if;

  insert into public.business_coverage (
    business_id,
    location_id
  )
  select
    p_business_id,
    location_id
  from unnest(p_location_ids) as location_id
  on conflict (business_id, location_id) do nothing;
end;
$$;

create or replace function public.replace_manageable_business_hours(
  p_business_id uuid,
  p_hours jsonb
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_item jsonb;
  v_day integer;
  v_is_closed boolean;
  v_open time;
  v_close time;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to manage business';
  end if;

  delete from public.business_hours
  where business_id = p_business_id;

  if p_hours is null then
    return;
  end if;

  for v_item in select * from jsonb_array_elements(p_hours) loop
    v_day := (v_item ->> 'day_of_week')::integer;
    v_is_closed := coalesce((v_item ->> 'is_closed')::boolean, false);
    v_open := nullif(v_item ->> 'open_time', '')::time;
    v_close := nullif(v_item ->> 'close_time', '')::time;

    insert into public.business_hours (
      business_id,
      day_of_week,
      open_time,
      close_time,
      is_closed
    )
    values (
      p_business_id,
      v_day,
      case when v_is_closed then null else v_open end,
      case when v_is_closed then null else v_close end,
      v_is_closed
    );
  end loop;
end;
$$;

grant execute on function public.update_manageable_business_profile(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text
) to authenticated;

grant execute on function public.replace_manageable_business_services(uuid, jsonb)
to authenticated;

grant execute on function public.replace_manageable_business_coverage(uuid, uuid[])
to authenticated;

grant execute on function public.replace_manageable_business_hours(uuid, jsonb)
to authenticated;
