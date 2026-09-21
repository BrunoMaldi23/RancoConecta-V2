-- ============================================================
-- RANCO CONECTA V2
-- Multivertical business model, capabilities, and monetization
-- ============================================================

alter type public.business_type add value if not exists 'tourism';
alter type public.business_type add value if not exists 'emergency';


-- ============================================================
-- 1. MEMBERSHIP PLANS: extensible commercial metadata
-- ============================================================

alter table public.membership_plans
  add column if not exists billing_period text not null default 'yearly',
  add column if not exists display_order integer not null default 0,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.membership_plans
  drop constraint if exists membership_plans_billing_period_check;

alter table public.membership_plans
  add constraint membership_plans_billing_period_check
  check (billing_period in ('none', 'monthly', 'yearly'));

create table if not exists public.plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id text not null,
  feature_key text not null,
  enabled boolean not null default true,
  limit_value integer,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plan_features_limit_non_negative
    check (limit_value is null or limit_value >= 0),
  unique (plan_id, feature_key)
);

create index if not exists plan_features_plan_idx
  on public.plan_features(plan_id);

drop trigger if exists plan_features_updated_at
  on public.plan_features;

create trigger plan_features_updated_at
before update on public.plan_features
for each row
execute function public.set_updated_at();


-- ============================================================
-- 2. COMMISSIONS: separate from memberships/subscriptions
-- ============================================================

create table if not exists public.commission_rules (
  id uuid primary key default gen_random_uuid(),
  business_type public.business_type not null,
  operation_type text not null,
  percentage_basis_points integer,
  fixed_fee integer,
  minimum_fee integer,
  maximum_fee integer,
  active boolean not null default true,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint commission_rules_operation_type_check
    check (operation_type in ('service', 'booking', 'quote', 'order')),
  constraint commission_rules_percentage_range
    check (
      percentage_basis_points is null
      or percentage_basis_points between 0 and 10000
    ),
  constraint commission_rules_amounts_non_negative
    check (
      (fixed_fee is null or fixed_fee >= 0)
      and (minimum_fee is null or minimum_fee >= 0)
      and (maximum_fee is null or maximum_fee >= 0)
    ),
  constraint commission_rules_valid_dates
    check (valid_until is null or valid_from < valid_until)
);

create index if not exists commission_rules_lookup_idx
  on public.commission_rules(business_type, operation_type, active);

drop trigger if exists commission_rules_updated_at
  on public.commission_rules;

create trigger commission_rules_updated_at
before update on public.commission_rules
for each row
execute function public.set_updated_at();


-- ============================================================
-- 3. SENSITIVE CHANGES: future review queue, no workflow yet
-- ============================================================

create table if not exists public.business_sensitive_change_requests (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete restrict,
  change_type text not null,
  current_value jsonb,
  requested_value jsonb not null,
  status text not null default 'submitted',
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_sensitive_change_status_check
    check (status in ('submitted', 'under_review', 'approved', 'rejected', 'cancelled'))
);

create index if not exists business_sensitive_change_business_idx
  on public.business_sensitive_change_requests(business_id, status);

drop trigger if exists business_sensitive_change_requests_updated_at
  on public.business_sensitive_change_requests;

create trigger business_sensitive_change_requests_updated_at
before update on public.business_sensitive_change_requests
for each row
execute function public.set_updated_at();


-- ============================================================
-- 4. BUSINESS OFFERS: promotion/destacado foundation
-- ============================================================

create table if not exists public.business_offers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  title text not null,
  description text,
  offer_type text not null default 'promotion',
  starts_at timestamptz,
  ends_at timestamptz,
  active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_offers_type_check
    check (offer_type in ('promotion')),
  constraint business_offers_dates_check
    check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create index if not exists business_offers_business_active_idx
  on public.business_offers(business_id, active);

drop trigger if exists business_offers_updated_at
  on public.business_offers;

create trigger business_offers_updated_at
before update on public.business_offers
for each row
execute function public.set_updated_at();

create table if not exists public.featured_placements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  placement_key text not null,
  status text not null default 'draft',
  starts_at timestamptz,
  ends_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint featured_placements_status_check
    check (status in ('draft', 'scheduled', 'active', 'paused', 'expired', 'cancelled')),
  constraint featured_placements_dates_check
    check (starts_at is null or ends_at is null or starts_at < ends_at)
);

create index if not exists featured_placements_lookup_idx
  on public.featured_placements(placement_key, status, starts_at, ends_at);

drop trigger if exists featured_placements_updated_at
  on public.featured_placements;

create trigger featured_placements_updated_at
before update on public.featured_placements
for each row
execute function public.set_updated_at();


-- ============================================================
-- 5. RLS helper and policies
-- ============================================================

create or replace function public.user_can_manage_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members bm
    where bm.business_id = p_business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'manager')
  )
  or exists (
    select 1
    from public.businesses b
    where b.id = p_business_id
      and b.owner_id = auth.uid()
  );
$$;

create or replace function public.protect_business_sensitive_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if auth.role() <> 'service_role' and (
    new.owner_id <> old.owner_id
    or new.business_type <> old.business_type
    or new.publication_status <> old.publication_status
    or new.verification_status <> old.verification_status
  ) then
    raise exception 'sensitive business fields require a privileged server-side operation';
  end if;

  return new;
end;
$$;

drop trigger if exists businesses_protect_sensitive_fields
  on public.businesses;

create trigger businesses_protect_sensitive_fields
before update on public.businesses
for each row
execute function public.protect_business_sensitive_fields();

drop policy if exists "owners update businesses"
  on public.businesses;

drop policy if exists "active managers update business profile"
  on public.businesses;

create policy "active managers update business profile"
on public.businesses
for update
using (public.user_can_manage_business(id))
with check (public.user_can_manage_business(id));

drop policy if exists "active managers manage business services"
  on public.business_services;

create policy "active managers manage business services"
on public.business_services
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "active managers manage business coverage"
  on public.business_coverage;

create policy "active managers manage business coverage"
on public.business_coverage
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "active managers manage business hours"
  on public.business_hours;

create policy "active managers manage business hours"
on public.business_hours
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "active managers manage business media"
  on public.business_media;

create policy "active managers manage business media"
on public.business_media
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

alter table public.plan_features enable row level security;
alter table public.commission_rules enable row level security;
alter table public.business_sensitive_change_requests enable row level security;
alter table public.business_offers enable row level security;
alter table public.featured_placements enable row level security;

drop policy if exists "public read enabled plan features"
  on public.plan_features;

create policy "public read enabled plan features"
on public.plan_features
for select
using (
  enabled
  and exists (
    select 1
    from public.membership_plans mp
    where mp.id::text = plan_features.plan_id
      and mp.active
  )
);

drop policy if exists "public read active commission rules"
  on public.commission_rules;

create policy "public read active commission rules"
on public.commission_rules
for select
using (active);

drop policy if exists "business managers create sensitive change requests"
  on public.business_sensitive_change_requests;

create policy "business managers create sensitive change requests"
on public.business_sensitive_change_requests
for insert
with check (
  requested_by = auth.uid()
  and public.user_can_manage_business(business_id)
);

drop policy if exists "business managers read sensitive change requests"
  on public.business_sensitive_change_requests;

create policy "business managers read sensitive change requests"
on public.business_sensitive_change_requests
for select
using (public.user_can_manage_business(business_id));

drop policy if exists "public read active published business offers"
  on public.business_offers;

create policy "public read active published business offers"
on public.business_offers
for select
using (
  active
  and exists (
    select 1
    from public.businesses b
    where b.id = business_offers.business_id
      and b.publication_status = 'published'
  )
);

drop policy if exists "business managers manage offers"
  on public.business_offers;

create policy "business managers manage offers"
on public.business_offers
for all
using (public.user_can_manage_business(business_id))
with check (public.user_can_manage_business(business_id));

drop policy if exists "public read active featured placements"
  on public.featured_placements;

create policy "public read active featured placements"
on public.featured_placements
for select
using (
  status = 'active'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at > now())
  and exists (
    select 1
    from public.businesses b
    where b.id = featured_placements.business_id
      and b.publication_status = 'published'
  )
);

grant select
on public.plan_features,
   public.commission_rules
to anon, authenticated;

grant select, insert
on public.business_sensitive_change_requests
to authenticated;

grant select, insert, update, delete
on public.business_offers
to authenticated;

grant select
on public.featured_placements
to anon, authenticated;

grant execute on function public.user_can_manage_business(uuid)
to authenticated;


-- ============================================================
-- END
-- ============================================================
