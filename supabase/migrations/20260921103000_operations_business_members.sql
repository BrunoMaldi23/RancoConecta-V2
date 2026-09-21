-- ============================================================
-- RANCO CONECTA V2
-- Operations core and business memberships
-- ============================================================

create extension if not exists pgcrypto;


-- ============================================================
-- 1. OPERATIONS
-- ============================================================

create table if not exists public.operations (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  business_id uuid references public.businesses(id) on delete restrict,
  status text not null default 'draft',
  currency char(3) not null default 'CLP',
  subtotal integer not null default 0,
  platform_fee integer not null default 0,
  discount integer not null default 0,
  total integer not null default 0,
  payment_status text not null default 'not_required',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint operations_type_check check (
    type in ('service', 'booking', 'quote', 'order')
  ),
  constraint operations_status_check check (
    status in (
      'draft',
      'submitted',
      'pending',
      'reviewing',
      'accepted',
      'scheduled',
      'in_progress',
      'completed',
      'confirmed',
      'closed',
      'cancelled',
      'rejected',
      'expired',
      'disputed'
    )
  ),
  constraint operations_payment_status_check check (
    payment_status in (
      'not_required',
      'pending',
      'processing',
      'authorized',
      'paid',
      'failed',
      'cancelled',
      'refunded',
      'disputed'
    )
  ),
  constraint operations_amounts_non_negative check (
    subtotal >= 0
    and platform_fee >= 0
    and discount >= 0
    and total >= 0
  )
);

create index if not exists operations_customer_created_idx
  on public.operations(customer_id, created_at desc);

create index if not exists operations_business_created_idx
  on public.operations(business_id, created_at desc);

create index if not exists operations_type_status_idx
  on public.operations(type, status);

drop trigger if exists operations_updated_at
  on public.operations;

create trigger operations_updated_at
before update on public.operations
for each row
execute function public.set_updated_at();


-- ============================================================
-- 2. OPERATION EVENTS
-- ============================================================

create table if not exists public.operation_events (
  id uuid primary key default gen_random_uuid(),
  operation_id uuid not null references public.operations(id) on delete cascade,
  event_type text not null,
  actor_id uuid references public.profiles(id) on delete set null,
  previous_status text,
  new_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint operation_events_status_change_check check (
    previous_status is null
    or new_status is null
    or previous_status <> new_status
  )
);

create index if not exists operation_events_operation_created_idx
  on public.operation_events(operation_id, created_at);

create index if not exists operation_events_type_created_idx
  on public.operation_events(event_type, created_at desc);


-- ============================================================
-- 3. BUSINESS MEMBERS
-- ============================================================

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'staff',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_members_role_check check (
    role in ('owner', 'manager', 'staff')
  ),
  constraint business_members_status_check check (
    status in ('active', 'invited', 'suspended', 'removed')
  ),
  unique (business_id, user_id)
);

create index if not exists business_members_user_status_idx
  on public.business_members(user_id, status);

create index if not exists business_members_business_role_idx
  on public.business_members(business_id, role, status);

drop trigger if exists business_members_updated_at
  on public.business_members;

create trigger business_members_updated_at
before update on public.business_members
for each row
execute function public.set_updated_at();


-- Backfill current canonical owners. Existing businesses.owner_id remains the
-- source of truth until provider onboarding is migrated to a controlled flow.
insert into public.business_members (
  business_id,
  user_id,
  role,
  status
)
select
  b.id,
  b.owner_id,
  'owner',
  'active'
from public.businesses b
on conflict (business_id, user_id)
do update set
  role = 'owner',
  status = 'active';


-- ============================================================
-- 4. RLS
-- ============================================================

alter table public.operations enable row level security;
alter table public.operation_events enable row level security;
alter table public.business_members enable row level security;


-- BUSINESS MEMBERS

drop policy if exists "users read own business memberships"
  on public.business_members;

create policy "users read own business memberships"
on public.business_members
for select
using (
  user_id = auth.uid()
);


-- BUSINESSES MEMBERSHIP READ ACCESS

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


-- OPERATIONS

drop policy if exists "operation customers read own operations"
  on public.operations;

create policy "operation customers read own operations"
on public.operations
for select
using (
  customer_id = auth.uid()
);


drop policy if exists "business members read related operations"
  on public.operations;

create policy "business members read related operations"
on public.operations
for select
using (
  business_id is not null
  and exists (
    select 1
    from public.business_members bm
    where bm.business_id = operations.business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
);


drop policy if exists "customers create draft operations"
  on public.operations;

create policy "customers create draft operations"
on public.operations
for insert
with check (
  customer_id = auth.uid()
  and status = 'draft'
  and payment_status = 'not_required'
);


-- OPERATION EVENTS

drop policy if exists "operation participants read events"
  on public.operation_events;

create policy "operation participants read events"
on public.operation_events
for select
using (
  exists (
    select 1
    from public.operations o
    where o.id = operation_events.operation_id
      and (
        o.customer_id = auth.uid()
        or (
          o.business_id is not null
          and exists (
            select 1
            from public.business_members bm
            where bm.business_id = o.business_id
              and bm.user_id = auth.uid()
              and bm.status = 'active'
          )
        )
      )
  )
);


-- ============================================================
-- 5. API PRIVILEGES
-- ============================================================

grant select, insert
on public.operations
to authenticated;

grant select
on public.operation_events
to authenticated;

grant select
on public.business_members
to authenticated;


-- ============================================================
-- END
-- ============================================================
