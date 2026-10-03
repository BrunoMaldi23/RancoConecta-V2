-- Admin access to the global review queue must not grant provider ownership.
-- Existing business rows, memberships and profile roles are left untouched.

create or replace function public.current_user_is_provider()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.account_status = 'active'
      and coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false
      and (
        p.role = 'provider'
        or (
          p.role = 'customer'
          and (
            exists (
              select 1 from public.businesses b
              where b.owner_id = auth.uid()
            )
            or exists (
              select 1 from public.business_members bm
              where bm.user_id = auth.uid()
                and bm.status = 'active'
                and bm.role in ('owner', 'manager')
            )
          )
        )
      )
  );
$$;

revoke all on function public.current_user_is_provider() from public, anon;
grant execute on function public.current_user_is_provider() to authenticated;

create or replace function public.user_can_manage_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select public.current_user_is_provider() and (
    exists (
      select 1 from public.business_members bm
      where bm.business_id = p_business_id
        and bm.user_id = auth.uid()
        and bm.status = 'active'
        and bm.role in ('owner', 'manager')
    )
    or exists (
      select 1 from public.businesses b
      where b.id = p_business_id and b.owner_id = auth.uid()
    )
  );
$$;

create or replace function public.my_manageable_businesses()
returns table(
  id uuid,
  name text,
  business_type text,
  publication_status text,
  submitted_at timestamptz,
  changes_requested_note text,
  membership_role text,
  membership_status text,
  created_at timestamptz
)
language sql
security definer
set search_path = public, auth
stable
as $$
  select distinct on (b.id)
    b.id, b.name, b.business_type::text, b.publication_status::text,
    b.submitted_at, b.changes_requested_note,
    coalesce(bm.role, 'owner') as membership_role,
    coalesce(bm.status, 'active') as membership_status,
    b.created_at
  from public.businesses b
  left join public.business_members bm
    on bm.business_id = b.id and bm.user_id = auth.uid()
  where public.current_user_is_provider()
    and (
      (bm.user_id = auth.uid() and bm.status = 'active'
        and bm.role in ('owner', 'manager'))
      or b.owner_id = auth.uid()
    )
  order by b.id, b.created_at desc;
$$;

-- The one-business RPC delegates to my_manageable_businesses(), so it now
-- inherits the provider-role requirement without changing its contract.

-- Legacy owner policies could otherwise still allow a historical admin owner
-- to write provider data directly, even though the provider RPC is denied.
drop policy if exists "owners insert businesses" on public.businesses;
drop policy if exists "owners update businesses" on public.businesses;
create policy "providers insert own businesses"
on public.businesses for insert to authenticated
with check (
  public.current_user_is_provider()
  and owner_id = auth.uid()
  and publication_status in ('draft', 'pending_review')
);

drop policy if exists "owners manage business services" on public.business_services;
drop policy if exists "owners manage business coverage" on public.business_coverage;
drop policy if exists "owners manage business hours" on public.business_hours;
drop policy if exists "owners manage business media" on public.business_media;

drop policy if exists "providers read directed requests" on public.service_requests;
create policy "providers read directed requests"
on public.service_requests for select to authenticated
using (
  business_id is not null
  and public.user_can_manage_business(business_id)
);

drop policy if exists "owners update lodging details" on public.lodging_details;
drop policy if exists "owners insert lodging details" on public.lodging_details;
drop policy if exists "public read lodging details" on public.lodging_details;
create policy "public read lodging details"
on public.lodging_details for select
using (
  exists (
    select 1 from public.businesses b
    where b.id = lodging_details.business_id
      and b.publication_status = 'published'
  ) or public.user_can_manage_business(business_id)
);
create policy "providers insert lodging details"
on public.lodging_details for insert to authenticated
with check (public.user_can_manage_business(business_id));
create policy "providers update lodging details"
on public.lodging_details for update to authenticated
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "owners insert lodging calendar" on public.lodging_calendar;
drop policy if exists "owners update lodging calendar" on public.lodging_calendar;
drop policy if exists "owners delete lodging calendar" on public.lodging_calendar;
drop policy if exists "public read lodging calendar" on public.lodging_calendar;
create policy "public read lodging calendar"
on public.lodging_calendar for select
using (
  exists (
    select 1 from public.businesses b
    where b.id = lodging_calendar.business_id
      and b.publication_status = 'published'
  ) or public.user_can_manage_business(business_id)
);
create policy "providers insert lodging calendar"
on public.lodging_calendar for insert to authenticated
with check (public.user_can_manage_business(business_id));
create policy "providers update lodging calendar"
on public.lodging_calendar for update to authenticated
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));
create policy "providers delete lodging calendar"
on public.lodging_calendar for delete to authenticated
using (public.user_can_manage_business(business_id));

drop policy if exists "owners read lodging bookings" on public.lodging_bookings;
create policy "providers read lodging bookings"
on public.lodging_bookings for select to authenticated
using (public.user_can_manage_business(business_id));

drop policy if exists "business members read related operations" on public.operations;
create policy "providers read related operations"
on public.operations for select to authenticated
using (business_id is not null and public.user_can_manage_business(business_id));

drop policy if exists "providers read compatible service requests"
on public.service_requests;
create policy "providers read compatible service requests"
on public.service_requests for select to authenticated
using (
  public.current_user_is_provider()
  and exists (
    select 1 from public.business_members bm
    where bm.user_id = auth.uid()
      and bm.status = 'active'
      and public.user_can_manage_business(bm.business_id)
      and public.request_is_visible_to_business(service_requests.id, bm.business_id)
  )
);

drop policy if exists "lodging owners upload business media" on storage.objects;
drop policy if exists "lodging owners update business media" on storage.objects;
drop policy if exists "lodging owners delete business media" on storage.objects;
create policy "providers upload business media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(name))[2]
      and public.user_can_manage_business(b.id)
  )
);
create policy "providers update business media"
on storage.objects for update to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(name))[2]
      and public.user_can_manage_business(b.id)
  )
)
with check (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(name))[2]
      and public.user_can_manage_business(b.id)
  )
);
create policy "providers delete business media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'business-media'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.businesses b
    where b.id::text = (storage.foldername(name))[2]
      and public.user_can_manage_business(b.id)
  )
);

-- Keep the established booking transitions, but gate their callable entry
-- points by provider role and business ownership before invoking them.
alter function public.accept_lodging_booking(uuid)
rename to accept_lodging_booking_unchecked;
revoke all on function public.accept_lodging_booking_unchecked(uuid)
from public, anon, authenticated;
create function public.accept_lodging_booking(p_booking_id uuid)
returns void language plpgsql security definer set search_path = public, auth
as $$
declare v_business_id uuid;
begin
  select business_id into v_business_id
  from public.lodging_bookings where id = p_booking_id;
  if v_business_id is null or not public.user_can_manage_business(v_business_id) then
    raise exception 'provider access required' using errcode = '42501';
  end if;
  perform public.accept_lodging_booking_unchecked(p_booking_id);
end;
$$;
revoke all on function public.accept_lodging_booking(uuid) from public, anon;
grant execute on function public.accept_lodging_booking(uuid) to authenticated;

alter function public.reject_lodging_booking(uuid)
rename to reject_lodging_booking_unchecked;
revoke all on function public.reject_lodging_booking_unchecked(uuid)
from public, anon, authenticated;
create function public.reject_lodging_booking(p_booking_id uuid)
returns void language plpgsql security definer set search_path = public, auth
as $$
declare v_business_id uuid;
begin
  select business_id into v_business_id
  from public.lodging_bookings where id = p_booking_id;
  if v_business_id is null or not public.user_can_manage_business(v_business_id) then
    raise exception 'provider access required' using errcode = '42501';
  end if;
  perform public.reject_lodging_booking_unchecked(p_booking_id);
end;
$$;
revoke all on function public.reject_lodging_booking(uuid) from public, anon;
grant execute on function public.reject_lodging_booking(uuid) to authenticated;

-- The draft RPC is SECURITY DEFINER and needs its own role gate.
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
    raise exception 'invalid business_type: %', p_business_type;
  end;

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
