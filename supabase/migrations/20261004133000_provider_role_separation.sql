-- Existing business owners/managers were historically left as customer.
-- Bring their stored role in line with the product role before tightening access.
select set_config('ranco.admin_profile_write', 'on', true);
update public.profiles p set role = 'provider'
where p.role = 'customer'
  and exists (
    select 1 from public.businesses b where b.owner_id = p.id
    union all
    select 1 from public.business_members bm
    where bm.user_id = p.id and bm.status = 'active'
      and bm.role in ('owner', 'manager')
  );
select set_config('ranco.admin_profile_write', 'off', true);

create or replace function public.register_provider_identity()
returns void
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_user_id uuid := auth.uid();
  v_role public.app_role;
begin
  if v_user_id is null
     or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true' then
    raise exception 'provider access required' using errcode = '42501';
  end if;
  select p.role into v_role from public.profiles p
  where p.id = v_user_id and p.account_status = 'active' for update;
  if not found or v_role not in ('customer', 'provider') then
    raise exception 'provider access required' using errcode = '42501';
  end if;
  if v_role = 'provider' then return; end if;
  perform set_config('ranco.admin_profile_write', 'on', true);
  update public.profiles set role = 'provider' where id = v_user_id;
  perform set_config('ranco.admin_profile_write', 'off', true);
  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_user_id, 'provider_identity_registered', 'profile', v_user_id,
    jsonb_build_object('role', 'customer'),
    jsonb_build_object('role', 'provider')
  );
end;
$$;

revoke all on function public.register_provider_identity()
from public, anon, authenticated, service_role;
grant execute on function public.register_provider_identity()
to authenticated;

create or replace function public.current_user_is_provider()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'provider'
        and p.account_status = 'active'
    );
$$;

create or replace function public.create_business_draft(
  p_business_type text, p_name text default null
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
  if not public.current_user_is_provider() then
    raise exception 'provider access required' using errcode = '42501';
  end if;
  begin
    v_business_type := p_business_type::public.business_type;
  exception when invalid_text_representation then
    raise exception 'invalid business_type' using errcode = '22023';
  end;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));
  select b.id into v_business_id from public.businesses b
  where b.owner_id = v_user_id and b.publication_status = 'draft'
  order by b.created_at, b.id limit 1;
  if v_business_id is not null then return v_business_id; end if;
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

create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if new.role = 'customer' and old.role <> 'customer'
     and (exists (select 1 from public.businesses b where b.owner_id = old.id)
       or exists (select 1 from public.business_members bm
         where bm.user_id = old.id and bm.status = 'active'
           and bm.role in ('owner', 'manager'))) then
    raise exception 'PROVIDER_HAS_BUSINESS' using errcode = '23514';
  end if;
  if (new.role <> old.role or new.account_status <> old.account_status)
     and auth.role() <> 'service_role'
     and not (
       current_user = 'postgres'
       and current_setting('ranco.admin_profile_write', true) = 'on'
     ) then
    raise exception 'profile role and account status require a privileged server-side operation'
      using errcode = '42501';
  end if;
  return new;
end;
$$;
