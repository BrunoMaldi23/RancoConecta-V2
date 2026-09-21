-- ============================================================
-- RANCO CONECTA V2
-- Business onboarding RPCs and review submission
-- ============================================================

alter type public.publication_status add value if not exists 'changes_requested';

alter table public.businesses
  add column if not exists primary_category_id uuid references public.categories(id) on delete restrict,
  add column if not exists address_text text,
  add column if not exists onboarding_metadata jsonb not null default '{}'::jsonb,
  add column if not exists submitted_at timestamptz,
  add column if not exists changes_requested_note text;

create index if not exists businesses_primary_category_idx
  on public.businesses(primary_category_id);

create extension if not exists unaccent;

create or replace function public.slugify_business_name(p_name text)
returns text
language sql
stable
set search_path = public
as $$
  select trim(both '-' from regexp_replace(lower(unaccent(coalesce(p_name, 'negocio'))), '[^a-z0-9]+', '-', 'g'));
$$;

create or replace function public.next_business_slug(p_name text)
returns text
language plpgsql
set search_path = public
as $$
declare
  v_base text;
  v_slug text;
  v_suffix integer := 0;
begin
  v_base := public.slugify_business_name(p_name);

  if v_base is null or v_base = '' then
    v_base := 'negocio';
  end if;

  v_slug := v_base;

  while exists (select 1 from public.businesses b where b.slug = v_slug) loop
    v_suffix := v_suffix + 1;
    v_slug := v_base || '-' || v_suffix::text;
  end loop;

  return v_slug;
end;
$$;


create or replace function public.create_business_draft(
  p_business_type text,
  p_name text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_business_type public.business_type;
  v_business_id uuid;
  v_name text;
begin
  if v_user_id is null then
    raise exception 'authentication required';
  end if;

  begin
    v_business_type := p_business_type::public.business_type;
  exception
    when invalid_text_representation then
      raise exception 'invalid business_type: %', p_business_type;
  end;

  v_name := nullif(trim(coalesce(p_name, '')), '');

  if v_name is null then
    v_name := 'Nuevo negocio';
  end if;

  insert into public.businesses (
    owner_id,
    business_type,
    name,
    slug,
    publication_status,
    verification_status
  )
  values (
    v_user_id,
    v_business_type,
    v_name,
    public.next_business_slug(v_name),
    'draft',
    'unverified'
  )
  returning id into v_business_id;

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status
  )
  values (
    v_business_id,
    v_user_id,
    'owner',
    'active'
  )
  on conflict (business_id, user_id)
  do update set
    role = 'owner',
    status = 'active';

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  )
  values (
    v_user_id,
    'business_created',
    'business',
    v_business_id,
    jsonb_build_object('business_type', v_business_type, 'status', 'draft')
  );

  return v_business_id;
end;
$$;


create or replace function public.update_business_draft(
  p_business_id uuid,
  p_name text default null,
  p_description text default null,
  p_phone text default null,
  p_whatsapp text default null,
  p_email text default null,
  p_website text default null,
  p_primary_category_id uuid default null,
  p_address_text text default null,
  p_coverage_location_ids uuid[] default null,
  p_service_items jsonb default null,
  p_lodging_details jsonb default null,
  p_onboarding_metadata jsonb default '{}'::jsonb
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_item jsonb;
  v_subcategory_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select *
  into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to manage business';
  end if;

  if v_business.publication_status::text not in ('draft', 'changes_requested') then
    raise exception 'only draft or changes_requested businesses can use onboarding updates';
  end if;

  update public.businesses
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    slug = case
      when p_name is not null and nullif(trim(p_name), '') is not null and p_name <> name
        then public.next_business_slug(p_name)
      else slug
    end,
    description = nullif(trim(coalesce(p_description, description)), ''),
    phone = nullif(trim(coalesce(p_phone, phone)), ''),
    whatsapp = nullif(trim(coalesce(p_whatsapp, whatsapp)), ''),
    email = nullif(trim(coalesce(p_email, email)), ''),
    website = nullif(trim(coalesce(p_website, website)), ''),
    primary_category_id = coalesce(p_primary_category_id, primary_category_id),
    address_text = nullif(trim(coalesce(p_address_text, address_text)), ''),
    onboarding_metadata = coalesce(onboarding_metadata, '{}'::jsonb)
      || coalesce(p_onboarding_metadata, '{}'::jsonb)
  where id = p_business_id
  returning * into v_business;

  if p_coverage_location_ids is not null then
    delete from public.business_coverage
    where business_id = p_business_id;

    insert into public.business_coverage (
      business_id,
      location_id
    )
    select
      p_business_id,
      location_id
    from unnest(p_coverage_location_ids) as location_id
    on conflict (business_id, location_id) do nothing;
  end if;

  if p_service_items is not null then
    delete from public.business_services
    where business_id = p_business_id;

    for v_item in select * from jsonb_array_elements(p_service_items) loop
      v_subcategory_id := (v_item ->> 'subcategory_id')::uuid;

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
  end if;

  if p_lodging_details is not null and v_business.business_type = 'lodging' then
    update public.lodging_details
    set
      max_guests = coalesce((p_lodging_details ->> 'max_guests')::integer, max_guests),
      included_guests = coalesce((p_lodging_details ->> 'included_guests')::integer, included_guests),
      bedrooms = coalesce((p_lodging_details ->> 'bedrooms')::integer, bedrooms),
      beds = coalesce((p_lodging_details ->> 'beds')::integer, beds),
      bathrooms = coalesce((p_lodging_details ->> 'bathrooms')::numeric, bathrooms),
      price_per_night = coalesce((p_lodging_details ->> 'price_per_night')::integer, price_per_night),
      check_in_time = coalesce((p_lodging_details ->> 'check_in_time')::time, check_in_time),
      check_out_time = coalesce((p_lodging_details ->> 'check_out_time')::time, check_out_time),
      min_nights = coalesce((p_lodging_details ->> 'min_nights')::integer, min_nights)
    where business_id = p_business_id;
  end if;

  return v_business;
end;
$$;


create or replace function public.business_review_requirements(p_business_id uuid)
returns table (
  requirement_key text,
  satisfied boolean,
  message text
)
language sql
stable
security definer
set search_path = public
as $$
  with b as (
    select *
    from public.businesses
    where id = p_business_id
  )
  select 'name', exists(select 1 from b where length(trim(name)) >= 3), 'Agrega el nombre comercial.'
  union all
  select 'description', exists(select 1 from b where length(trim(coalesce(description, ''))) >= 20), 'Agrega una descripcion mas completa.'
  union all
  select 'category', exists(select 1 from b where primary_category_id is not null), 'Selecciona una categoria.'
  union all
  select 'contact', exists(select 1 from b where coalesce(phone, whatsapp, email) is not null), 'Agrega telefono, WhatsApp o email.'
  union all
  select 'coverage', exists(select 1 from public.business_coverage bc where bc.business_id = p_business_id), 'Selecciona al menos una localidad.'
  union all
  select 'service_items',
    case
      when exists(select 1 from b where business_type = 'service')
        then exists(select 1 from public.business_services bs where bs.business_id = p_business_id and bs.active)
      else true
    end,
    'Selecciona al menos un servicio.'
  union all
  select 'lodging_details',
    case
      when exists(select 1 from b where business_type = 'lodging')
        then exists(
          select 1
          from public.lodging_details ld
          where ld.business_id = p_business_id
            and ld.price_per_night > 0
            and ld.max_guests > 0
            and ld.bedrooms > 0
            and ld.beds > 0
        )
      else true
    end,
    'Completa detalles y tarifa base del alojamiento.';
$$;


create or replace function public.submit_business_for_review(
  p_business_id uuid
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_missing text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select *
  into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized to submit business';
  end if;

  if v_business.publication_status::text not in ('draft', 'changes_requested') then
    raise exception 'business cannot be submitted from status %', v_business.publication_status;
  end if;

  select string_agg(requirement_key, ', ')
  into v_missing
  from public.business_review_requirements(p_business_id)
  where not satisfied;

  if v_missing is not null then
    raise exception 'missing requirements: %', v_missing;
  end if;

  update public.businesses
  set
    publication_status = 'pending_review',
    submitted_at = now(),
    changes_requested_note = null
  where id = p_business_id
  returning * into v_business;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  )
  values (
    auth.uid(),
    'business_submitted',
    'business',
    p_business_id,
    jsonb_build_object('status', 'pending_review')
  );

  return v_business;
end;
$$;


grant execute on function public.create_business_draft(text, text)
to authenticated;

grant execute on function public.update_business_draft(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  text,
  uuid[],
  jsonb,
  jsonb,
  jsonb
)
to authenticated;

grant execute on function public.business_review_requirements(uuid)
to authenticated;

grant execute on function public.submit_business_for_review(uuid)
to authenticated;


create or replace function public.user_can_manage_business_path(p_path text)
returns boolean
language plpgsql
stable
security definer
set search_path = public, storage
as $$
declare
  v_business_id uuid;
begin
  v_business_id := (storage.foldername(p_path))[1]::uuid;
  return public.user_can_manage_business(v_business_id);
exception
  when others then
    return false;
end;
$$;

grant execute on function public.user_can_manage_business_path(text)
to authenticated;


-- STORAGE: generalized business-media ownership.

drop policy if exists "business managers upload business media"
  on storage.objects;

create policy "business managers upload business media"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'business-media'
  and public.user_can_manage_business_path(name)
);

drop policy if exists "business managers update business media"
  on storage.objects;

create policy "business managers update business media"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'business-media'
  and public.user_can_manage_business_path(name)
)
with check (
  bucket_id = 'business-media'
  and public.user_can_manage_business_path(name)
);

drop policy if exists "business managers delete business media"
  on storage.objects;

create policy "business managers delete business media"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'business-media'
  and public.user_can_manage_business_path(name)
);

-- ============================================================
-- END
-- ============================================================
