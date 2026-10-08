-- A provider account exists before its first business. The signup metadata is
-- read once by the auth trigger; later client metadata edits cannot change role.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, role, account_status)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    case when coalesce(new.is_anonymous, false) = false
      and new.raw_user_meta_data ->> 'provider_registration' = 'true'
      then 'provider'::public.app_role
      else 'customer'::public.app_role end,
    'active'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Serialize attempts for one owner. Repeated clicks and parallel requests
-- return the same editable draft without inserting another business or audit.
create or replace function public.create_business_draft(
  p_business_type text,
  p_name text default null
)
returns uuid
language plpgsql security definer
set search_path = public, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_business_type public.business_type;
  v_business_id uuid;
  v_name text;
begin
  if v_user_id is null or not exists (
    select 1 from public.profiles p
    where p.id = v_user_id
      and p.account_status = 'active'
      and p.role in ('customer', 'provider')
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
  ) then
    raise exception 'provider access required' using errcode = '42501';
  end if;

  begin
    v_business_type := p_business_type::public.business_type;
  exception when invalid_text_representation then
    raise exception 'invalid business_type' using errcode = '22023';
  end;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select b.id into v_business_id
  from public.businesses b
  where b.owner_id = v_user_id and b.publication_status = 'draft'
  order by b.created_at, b.id
  limit 1;
  if v_business_id is not null then
    return v_business_id;
  end if;

  v_name := nullif(trim(coalesce(p_name, '')), '');
  if v_name is null then v_name := 'Nuevo negocio'; end if;
  insert into public.businesses (
    owner_id, business_type, name, slug,
    publication_status, verification_status
  ) values (
    v_user_id, v_business_type, v_name,
    public.next_business_slug(v_name), 'draft', 'unverified'
  ) returning id into v_business_id;

  insert into public.business_members (business_id, user_id, role, status)
  values (v_business_id, v_user_id, 'owner', 'active')
  on conflict (business_id, user_id)
  do update set role = 'owner', status = 'active';

  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_user_id, 'business_created', 'business', v_business_id,
    jsonb_build_object('business_type', v_business_type, 'status', 'draft')
  );
  return v_business_id;
end;
$$;
