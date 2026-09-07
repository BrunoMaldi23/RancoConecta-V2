create extension if not exists pgcrypto;

create type app_role as enum ('customer', 'provider', 'admin', 'super_admin');
create type account_status as enum ('active', 'pending', 'suspended', 'blocked', 'deleted');
create type business_type as enum ('service', 'commerce', 'gastronomy', 'lodging');
create type publication_status as enum ('draft', 'pending_review', 'published', 'paused', 'rejected', 'suspended', 'archived');
create type verification_status as enum ('unverified', 'pending', 'verified', 'rejected');
create type media_type as enum ('logo', 'cover', 'gallery', 'portfolio');
create type request_urgency as enum ('low', 'normal', 'high', 'urgent');
create type service_request_status as enum ('draft', 'submitted', 'viewed', 'quoted', 'accepted', 'scheduled', 'in_progress', 'completed', 'confirmed', 'reviewed', 'rejected', 'cancelled', 'expired', 'disputed');
create type quote_status as enum ('pending', 'accepted', 'rejected', 'expired', 'cancelled');
create type membership_status as enum ('pending', 'active', 'expired', 'cancelled');
create type payment_provider as enum ('webpay');
create type payment_status as enum ('pending', 'processing', 'authorized', 'failed', 'cancelled');
create type message_type as enum ('text', 'image', 'system', 'quote', 'location');

create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create sequence service_request_public_code_seq;

create or replace function generate_service_request_public_code()
returns text
language plpgsql
set search_path = public
as $$
begin
  return 'RC-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('service_request_public_code_seq')::text, 6, '0');
end;
$$;

create or replace function protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if auth.role() <> 'service_role' and (new.role <> old.role or new.account_status <> old.account_status) then
    raise exception 'profile role and account status require a privileged server-side operation';
  end if;

  return new;
end;
$$;

create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.profiles (id, full_name, role, account_status)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    'customer',
    'active'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_url text,
  role app_role not null default 'customer',
  account_status account_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table regions (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table communes (
  id uuid primary key default gen_random_uuid(),
  region_id uuid not null references regions(id) on delete restrict,
  name text not null,
  slug text not null unique,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table locations (
  id uuid primary key default gen_random_uuid(),
  commune_id uuid not null references communes(id) on delete restrict,
  name text not null,
  slug text not null unique,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  icon_key text not null,
  theme_key text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references categories(id) on delete cascade,
  name text not null,
  slug text not null unique,
  description text,
  icon_key text not null,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete restrict,
  business_type business_type not null,
  name text not null,
  slug text not null unique,
  description text,
  phone text,
  whatsapp text,
  email text,
  website text,
  publication_status publication_status not null default 'draft',
  verification_status verification_status not null default 'unverified',
  latitude numeric(9,6),
  longitude numeric(9,6),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint businesses_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint businesses_longitude_range check (longitude is null or longitude between -180 and 180)
);

create table business_services (
  business_id uuid not null references businesses(id) on delete cascade,
  subcategory_id uuid not null references subcategories(id) on delete restrict,
  description text,
  price_from integer,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (business_id, subcategory_id),
  constraint business_services_price_non_negative check (price_from is null or price_from >= 0)
);

create table business_coverage (
  business_id uuid not null references businesses(id) on delete cascade,
  location_id uuid not null references locations(id) on delete restrict,
  radius_km numeric(6,2),
  created_at timestamptz not null default now(),
  primary key (business_id, location_id),
  constraint business_coverage_radius_positive check (radius_km is null or radius_km > 0)
);

create table business_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  day_of_week smallint not null,
  open_time time,
  close_time time,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint business_hours_day_range check (day_of_week between 1 and 7),
  constraint business_hours_time_required check (is_closed or (open_time is not null and close_time is not null and open_time < close_time)),
  unique (business_id, day_of_week)
);

create table business_media (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  media_type media_type not null,
  storage_path text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table service_requests (
  id uuid primary key default gen_random_uuid(),
  public_code text not null unique default generate_service_request_public_code(),
  customer_id uuid not null references profiles(id) on delete restrict,
  business_id uuid references businesses(id) on delete set null,
  category_id uuid not null references categories(id) on delete restrict,
  subcategory_id uuid not null references subcategories(id) on delete restrict,
  description text not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  address_text text,
  urgency request_urgency not null default 'normal',
  desired_date date,
  status service_request_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_requests_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint service_requests_longitude_range check (longitude is null or longitude between -180 and 180)
);

create table quotes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references service_requests(id) on delete cascade,
  business_id uuid not null references businesses(id) on delete cascade,
  labor_amount integer not null default 0,
  materials_amount integer not null default 0,
  travel_amount integer not null default 0,
  other_amount integer not null default 0,
  total_amount integer not null default 0,
  description text,
  estimated_duration text,
  proposed_at timestamptz,
  expires_at timestamptz,
  status quote_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint quotes_amounts_non_negative check (
    labor_amount >= 0 and materials_amount >= 0 and travel_amount >= 0 and other_amount >= 0 and total_amount >= 0
  ),
  unique (request_id, business_id)
);

create table favorites (
  user_id uuid not null references profiles(id) on delete cascade,
  business_id uuid not null references businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, business_id)
);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references service_requests(id) on delete restrict,
  customer_id uuid not null references profiles(id) on delete restrict,
  business_id uuid not null references businesses(id) on delete cascade,
  overall smallint not null,
  quality smallint not null,
  punctuality smallint not null,
  communication smallint not null,
  value_rating smallint not null,
  comment text,
  provider_reply text,
  verified_service boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reviews_rating_range check (
    overall between 1 and 5 and quality between 1 and 5 and punctuality between 1 and 5 and communication between 1 and 5 and value_rating between 1 and 5
  )
);

create table membership_plans (
  id text primary key,
  business_type business_type not null,
  name text not null,
  price_clp integer not null,
  duration_days integer not null,
  features jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint membership_plans_price_non_negative check (price_clp >= 0),
  constraint membership_plans_duration_positive check (duration_days > 0)
);

create table memberships (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete cascade,
  plan_id text not null references membership_plans(id) on delete restrict,
  status membership_status not null default 'pending',
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint memberships_dates_order check (starts_at is null or expires_at is null or starts_at < expires_at)
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references businesses(id) on delete restrict,
  membership_id uuid references memberships(id) on delete set null,
  provider payment_provider not null default 'webpay',
  external_order_id text not null unique,
  amount integer not null,
  currency char(3) not null default 'CLP',
  status payment_status not null default 'pending',
  authorization_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payments_amount_positive check (amount > 0)
);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  entity_type text,
  entity_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references service_requests(id) on delete cascade,
  customer_id uuid not null references profiles(id) on delete restrict,
  business_id uuid not null references businesses(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete restrict,
  message_type message_type not null default 'text',
  text text,
  attachment_path text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  constraint messages_content_present check (text is not null or attachment_path is not null or message_type in ('system', 'quote', 'location'))
);

insert into storage.buckets (id, name, public)
values
  ('business-media', 'business-media', true),
  ('request-attachments', 'request-attachments', false),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

create index businesses_owner_idx on businesses(owner_id);
create index businesses_type_status_idx on businesses(business_type, publication_status);
create index businesses_created_at_idx on businesses(created_at desc);
create index service_requests_customer_idx on service_requests(customer_id);
create index service_requests_business_idx on service_requests(business_id);
create index service_requests_status_created_idx on service_requests(status, created_at desc);
create index service_requests_subcategory_idx on service_requests(subcategory_id);
create index quotes_request_idx on quotes(request_id);
create index quotes_business_status_idx on quotes(business_id, status);
create index reviews_business_created_idx on reviews(business_id, created_at desc);
create index notifications_user_read_created_idx on notifications(user_id, read_at, created_at desc);
create index messages_conversation_created_idx on messages(conversation_id, created_at);

create trigger profiles_updated_at before update on profiles for each row execute function set_updated_at();
create trigger profiles_protect_privileged_fields before update on profiles for each row execute function protect_profile_privileged_fields();
create trigger auth_users_create_profile after insert on auth.users for each row execute function handle_new_auth_user();
create trigger regions_updated_at before update on regions for each row execute function set_updated_at();
create trigger communes_updated_at before update on communes for each row execute function set_updated_at();
create trigger locations_updated_at before update on locations for each row execute function set_updated_at();
create trigger categories_updated_at before update on categories for each row execute function set_updated_at();
create trigger subcategories_updated_at before update on subcategories for each row execute function set_updated_at();
create trigger businesses_updated_at before update on businesses for each row execute function set_updated_at();
create trigger business_services_updated_at before update on business_services for each row execute function set_updated_at();
create trigger business_hours_updated_at before update on business_hours for each row execute function set_updated_at();
create trigger service_requests_updated_at before update on service_requests for each row execute function set_updated_at();
create trigger quotes_updated_at before update on quotes for each row execute function set_updated_at();
create trigger reviews_updated_at before update on reviews for each row execute function set_updated_at();
create trigger membership_plans_updated_at before update on membership_plans for each row execute function set_updated_at();
create trigger memberships_updated_at before update on memberships for each row execute function set_updated_at();
create trigger payments_updated_at before update on payments for each row execute function set_updated_at();

alter table profiles enable row level security;
alter table regions enable row level security;
alter table communes enable row level security;
alter table locations enable row level security;
alter table categories enable row level security;
alter table subcategories enable row level security;
alter table businesses enable row level security;
alter table business_services enable row level security;
alter table business_coverage enable row level security;
alter table business_hours enable row level security;
alter table business_media enable row level security;
alter table service_requests enable row level security;
alter table quotes enable row level security;
alter table favorites enable row level security;
alter table reviews enable row level security;
alter table membership_plans enable row level security;
alter table memberships enable row level security;
alter table payments enable row level security;
alter table notifications enable row level security;
alter table audit_logs enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;

create policy "profiles select own" on profiles for select using (auth.uid() = id);
create policy "profiles update own basic fields" on profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "public read active regions" on regions for select using (active);
create policy "public read active communes" on communes for select using (active);
create policy "public read active locations" on locations for select using (active);
create policy "public read active categories" on categories for select using (active);
create policy "public read active subcategories" on subcategories for select using (active);

create policy "public read published businesses" on businesses for select using (publication_status = 'published');
create policy "owners read businesses" on businesses for select using (auth.uid() = owner_id);
create policy "owners insert businesses" on businesses for insert with check (auth.uid() = owner_id and publication_status in ('draft', 'pending_review'));
create policy "owners update businesses" on businesses for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id and publication_status in ('draft', 'pending_review', 'paused'));

create policy "public read published business services" on business_services for select using (
  exists (select 1 from businesses b where b.id = business_id and b.publication_status = 'published')
);
create policy "owners manage business services" on business_services for all using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
) with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "public read published business coverage" on business_coverage for select using (
  exists (select 1 from businesses b where b.id = business_id and b.publication_status = 'published')
);
create policy "owners manage business coverage" on business_coverage for all using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
) with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "public read published business hours" on business_hours for select using (
  exists (select 1 from businesses b where b.id = business_id and b.publication_status = 'published')
);
create policy "owners manage business hours" on business_hours for all using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
) with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "public read published business media" on business_media for select using (
  exists (select 1 from businesses b where b.id = business_id and b.publication_status = 'published')
);
create policy "owners manage business media" on business_media for all using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
) with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "customers read own service requests" on service_requests for select using (auth.uid() = customer_id);
create policy "providers read directed requests" on service_requests for select using (
  business_id is not null and exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);
create policy "customers create own service requests" on service_requests for insert with check (auth.uid() = customer_id);
create policy "customers update draft requests" on service_requests for update using (auth.uid() = customer_id and status = 'draft') with check (auth.uid() = customer_id and status in ('draft', 'submitted', 'cancelled'));

create policy "request participants read quotes" on quotes for select using (
  exists (select 1 from service_requests sr where sr.id = request_id and sr.customer_id = auth.uid())
  or exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);
create policy "business owners create quotes" on quotes for insert with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);
create policy "business owners update pending quotes" on quotes for update using (
  status = 'pending' and exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
) with check (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "users manage own favorites" on favorites for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "public read reviews" on reviews for select using (true);
create policy "customers create own reviews" on reviews for insert with check (
  auth.uid() = customer_id and exists (
    select 1 from service_requests sr where sr.id = request_id and sr.customer_id = auth.uid() and sr.business_id = reviews.business_id and sr.status in ('completed', 'confirmed', 'reviewed')
  )
);
create policy "public read active membership plans" on membership_plans for select using (active);
create policy "owners read own memberships" on memberships for select using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);
create policy "owners read own payments" on payments for select using (
  exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);

create policy "users read own notifications" on notifications for select using (auth.uid() = user_id);
create policy "users mark own notifications read" on notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "conversation participants read conversations" on conversations for select using (
  auth.uid() = customer_id or exists (select 1 from businesses b where b.id = business_id and b.owner_id = auth.uid())
);
create policy "conversation participants read messages" on messages for select using (
  exists (
    select 1 from conversations c
    join businesses b on b.id = c.business_id
    where c.id = conversation_id and (c.customer_id = auth.uid() or b.owner_id = auth.uid())
  )
);
create policy "conversation participants create messages" on messages for insert with check (
  auth.uid() = sender_id and exists (
    select 1 from conversations c
    join businesses b on b.id = c.business_id
    where c.id = conversation_id and (c.customer_id = auth.uid() or b.owner_id = auth.uid())
  )
);
