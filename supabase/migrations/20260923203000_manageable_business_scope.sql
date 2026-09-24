-- ============================================================
-- RANCO CONECTA V2
-- Canonical authenticated business administration scope
-- ============================================================

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
    b.id,
    b.name,
    b.business_type::text,
    b.publication_status::text,
    b.submitted_at,
    b.changes_requested_note,
    coalesce(bm.role, 'owner') as membership_role,
    coalesce(bm.status, 'active') as membership_status,
    b.created_at
  from public.businesses b
  left join public.business_members bm
    on bm.business_id = b.id
   and bm.user_id = auth.uid()
  where auth.uid() is not null
    and (
      (
        bm.user_id = auth.uid()
        and bm.status = 'active'
        and bm.role in ('owner', 'manager')
      )
      or b.owner_id = auth.uid()
    )
  order by b.id, b.created_at desc;
$$;

create or replace function public.my_manageable_business(
  p_business_id uuid
)
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
  select *
  from public.my_manageable_businesses() b
  where b.id = p_business_id
  limit 1;
$$;

drop policy if exists "users read own business memberships"
  on public.business_members;

create policy "users read own business memberships"
on public.business_members
for select
using (
  user_id = auth.uid()
  or public.is_admin()
);

drop policy if exists "active members read businesses"
  on public.businesses;

create policy "active members read businesses"
on public.businesses
for select
using (
  exists (
    select 1
    from public.business_members bm
    where bm.business_id = businesses.id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
);

grant execute on function public.my_manageable_businesses()
to authenticated;

grant execute on function public.my_manageable_business(uuid)
to authenticated;
