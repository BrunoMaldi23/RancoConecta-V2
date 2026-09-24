-- ============================================================
-- RANCO CONECTA V2
-- Service request quotes and operations workflow
-- ============================================================

alter table public.operations
  add column if not exists request_id uuid references public.service_requests(id) on delete restrict,
  add column if not exists quote_id uuid references public.quotes(id) on delete restrict,
  add column if not exists completed_at timestamptz;

create unique index if not exists operations_request_quote_unique_idx
  on public.operations(request_id, quote_id)
  where request_id is not null and quote_id is not null;

create unique index if not exists operations_request_unique_idx
  on public.operations(request_id)
  where request_id is not null;

create index if not exists service_requests_category_status_idx
  on public.service_requests(category_id, subcategory_id, status);

create index if not exists service_requests_created_status_idx
  on public.service_requests(created_at desc, status);

create index if not exists quotes_request_status_idx
  on public.quotes(request_id, status);

create index if not exists operations_request_idx
  on public.operations(request_id);

create index if not exists operations_quote_idx
  on public.operations(quote_id);


create or replace function public.create_direct_service_request(
  p_business_id uuid,
  p_category_id uuid,
  p_subcategory_id uuid,
  p_description text,
  p_address_text text,
  p_urgency text default 'normal',
  p_desired_date date default null
)
returns public.service_requests
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_request public.service_requests%rowtype;
  v_description text := nullif(trim(coalesce(p_description, '')), '');
  v_address text := nullif(trim(coalesce(p_address_text, '')), '');
  v_urgency text := coalesce(p_urgency, 'normal');
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if v_description is null or length(v_description) < 12 then
    raise exception 'description is too short';
  end if;

  if v_address is null then
    raise exception 'address is required';
  end if;

  if v_urgency not in ('low', 'normal', 'high', 'urgent') then
    raise exception 'invalid urgency';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id;

  if not found or v_business.publication_status::text <> 'published' then
    raise exception 'business is not available for requests';
  end if;

  if v_business.primary_category_id <> p_category_id then
    raise exception 'category does not match business';
  end if;

  if not exists (
    select 1
    from public.business_services bs
    where bs.business_id = p_business_id
      and bs.subcategory_id = p_subcategory_id
      and bs.active
  ) then
    raise exception 'business does not offer this service';
  end if;

  insert into public.service_requests (
    customer_id,
    business_id,
    category_id,
    subcategory_id,
    description,
    address_text,
    urgency,
    desired_date,
    status
  )
  values (
    auth.uid(),
    p_business_id,
    p_category_id,
    p_subcategory_id,
    v_description,
    v_address,
    v_urgency::public.request_urgency,
    p_desired_date,
    'submitted'
  )
  returning * into v_request;

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id
  )
  select
    bm.user_id,
    'service_request_created',
    'Nueva solicitud',
    'Recibiste una nueva solicitud directa.',
    'service_request',
    v_request.id
  from public.business_members bm
  where bm.business_id = p_business_id
    and bm.status = 'active'
    and bm.role in ('owner', 'manager');

  return v_request;
end;
$$;


create or replace function public.request_is_visible_to_business(
  p_request_id uuid,
  p_business_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.service_requests sr
    join public.businesses b on b.id = p_business_id
    where sr.id = p_request_id
      and b.publication_status = 'published'
      and (
        sr.business_id = b.id
        or (
          sr.business_id is null
          and sr.status in ('submitted', 'viewed', 'quoted')
          and exists (
            select 1
            from public.business_services bs
            where bs.business_id = b.id
              and bs.subcategory_id = sr.subcategory_id
              and bs.active
          )
        )
      )
  );
$$;


create or replace function public.find_matching_businesses_for_request(
  p_request_id uuid
)
returns table (
  business_id uuid,
  name text,
  category_name text,
  rating_avg numeric,
  is_featured boolean,
  verification_status text,
  match_reason text
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.service_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_request
  from public.service_requests
  where id = p_request_id;

  if not found then
    raise exception 'request not found';
  end if;

  if v_request.customer_id <> auth.uid()
    and not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    b.id,
    b.name,
    c.name,
    b.rating_avg,
    b.is_featured,
    b.verification_status::text,
    case
      when v_request.business_id = b.id then 'directed'
      else 'subcategory_and_coverage'
    end
  from public.businesses b
  join public.business_services bs
    on bs.business_id = b.id
   and bs.subcategory_id = v_request.subcategory_id
   and bs.active
  left join public.categories c on c.id = b.primary_category_id
  where b.publication_status = 'published'
    and (v_request.business_id is null or b.id = v_request.business_id)
  order by b.is_featured desc, b.rating_avg desc, b.created_at desc;
end;
$$;


create or replace function public.provider_service_request_queue(
  p_business_id uuid,
  p_status text default null
)
returns table (
  request_id uuid,
  public_code text,
  business_id uuid,
  category_id uuid,
  subcategory_id uuid,
  subcategory_name text,
  description text,
  address_text text,
  urgency text,
  desired_date date,
  request_status text,
  quote_id uuid,
  quote_status text,
  quote_total integer,
  operation_id uuid,
  operation_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized';
  end if;

  return query
  select
    sr.id,
    sr.public_code,
    p_business_id,
    sr.category_id,
    sr.subcategory_id,
    s.name,
    sr.description,
    sr.address_text,
    sr.urgency::text,
    sr.desired_date,
    sr.status::text,
    q.id,
    q.status::text,
    q.total_amount,
    o.id,
    o.status,
    sr.created_at
  from public.service_requests sr
  join public.subcategories s on s.id = sr.subcategory_id
  left join public.quotes q
    on q.request_id = sr.id
   and q.business_id = p_business_id
  left join public.operations o
    on o.request_id = sr.id
   and o.business_id = p_business_id
  where public.request_is_visible_to_business(sr.id, p_business_id)
    and (
      p_status is null
      or sr.status::text = p_status
      or q.status::text = p_status
      or o.status = p_status
    )
  order by sr.created_at desc;
end;
$$;


create or replace function public.provider_send_quote(
  p_request_id uuid,
  p_business_id uuid,
  p_description text,
  p_total_amount integer,
  p_expires_at timestamptz default null
)
returns public.quotes
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request public.service_requests%rowtype;
  v_quote public.quotes%rowtype;
  v_description text := nullif(trim(coalesce(p_description, '')), '');
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_manage_business(p_business_id) then
    raise exception 'not authorized';
  end if;

  if v_description is null then
    raise exception 'quote description is required';
  end if;

  if coalesce(p_total_amount, -1) < 0 then
    raise exception 'quote amount must be zero or greater';
  end if;

  select * into v_request
  from public.service_requests
  where id = p_request_id
  for update;

  if not found then
    raise exception 'request not found';
  end if;

  if v_request.status::text not in ('submitted', 'viewed', 'quoted') then
    raise exception 'request no longer accepts quotes';
  end if;

  if not public.request_is_visible_to_business(p_request_id, p_business_id) then
    raise exception 'business is not compatible with this request';
  end if;

  insert into public.quotes (
    request_id,
    business_id,
    total_amount,
    description,
    proposed_at,
    expires_at,
    status
  )
  values (
    p_request_id,
    p_business_id,
    p_total_amount,
    v_description,
    now(),
    p_expires_at,
    'pending'
  )
  on conflict (request_id, business_id)
  do update set
    total_amount = excluded.total_amount,
    description = excluded.description,
    proposed_at = now(),
    expires_at = excluded.expires_at,
    status = 'pending'
  where public.quotes.status = 'pending'
  returning * into v_quote;

  if v_quote.id is null then
    raise exception 'quote already responded';
  end if;

  update public.service_requests
  set status = 'quoted'
  where id = p_request_id
    and status in ('submitted', 'viewed', 'quoted');

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id
  )
  values (
    v_request.customer_id,
    'quote_received',
    'Nueva cotización',
    'Recibiste una cotización para tu solicitud ' || v_request.public_code || '.',
    'quote',
    v_quote.id
  );

  return v_quote;
end;
$$;


create or replace function public.accept_quote(
  p_quote_id uuid
)
returns public.operations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quote public.quotes%rowtype;
  v_request public.service_requests%rowtype;
  v_operation public.operations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_quote
  from public.quotes
  where id = p_quote_id
  for update;

  if not found then
    raise exception 'quote not found';
  end if;

  select * into v_request
  from public.service_requests
  where id = v_quote.request_id
  for update;

  if not found then
    raise exception 'request not found';
  end if;

  if v_request.customer_id <> auth.uid() then
    raise exception 'not authorized';
  end if;

  select * into v_operation
  from public.operations
  where request_id = v_request.id
  for update;

  if found then
    return v_operation;
  end if;

  if v_quote.status::text <> 'pending' then
    raise exception 'quote already responded';
  end if;

  if v_request.status::text not in ('quoted', 'viewed', 'submitted') then
    raise exception 'request no longer accepts quotes';
  end if;

  update public.quotes
  set status = 'accepted'
  where id = v_quote.id
  returning * into v_quote;

  update public.quotes
  set status = 'rejected'
  where request_id = v_request.id
    and id <> v_quote.id
    and status = 'pending';

  update public.service_requests
  set
    status = 'accepted',
    business_id = v_quote.business_id
  where id = v_request.id;

  insert into public.operations (
    type,
    customer_id,
    business_id,
    request_id,
    quote_id,
    status,
    subtotal,
    total,
    payment_status
  )
  values (
    'service',
    v_request.customer_id,
    v_quote.business_id,
    v_request.id,
    v_quote.id,
    'accepted',
    v_quote.total_amount,
    v_quote.total_amount,
    'not_required'
  )
  returning * into v_operation;

  insert into public.operation_events (
    operation_id,
    event_type,
    actor_id,
    previous_status,
    new_status,
    metadata
  )
  values (
    v_operation.id,
    'operation_created',
    auth.uid(),
    null,
    'accepted',
    jsonb_build_object('quote_id', v_quote.id, 'request_id', v_request.id)
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id
  )
  select
    bm.user_id,
    'quote_accepted',
    'Cotización aceptada',
    'Una cotización de tu negocio fue aceptada.',
    'operation',
    v_operation.id
  from public.business_members bm
  where bm.business_id = v_quote.business_id
    and bm.status = 'active'
    and bm.role in ('owner', 'manager');

  return v_operation;
end;
$$;


create or replace function public.provider_start_operation(
  p_operation_id uuid
)
returns public.operations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_operation public.operations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_operation
  from public.operations
  where id = p_operation_id
  for update;

  if not found then
    raise exception 'operation not found';
  end if;

  if not public.user_can_manage_business(v_operation.business_id) then
    raise exception 'not authorized';
  end if;

  if v_operation.status <> 'accepted' then
    raise exception 'operation cannot be started from status %', v_operation.status;
  end if;

  update public.operations
  set status = 'in_progress'
  where id = p_operation_id
  returning * into v_operation;

  update public.service_requests
  set status = 'in_progress'
  where id = v_operation.request_id;

  insert into public.operation_events (
    operation_id,
    event_type,
    actor_id,
    previous_status,
    new_status
  )
  values (p_operation_id, 'started', auth.uid(), 'accepted', 'in_progress');

  return v_operation;
end;
$$;


create or replace function public.provider_complete_operation(
  p_operation_id uuid
)
returns public.operations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_operation public.operations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_operation
  from public.operations
  where id = p_operation_id
  for update;

  if not found then
    raise exception 'operation not found';
  end if;

  if not public.user_can_manage_business(v_operation.business_id) then
    raise exception 'not authorized';
  end if;

  if v_operation.status <> 'in_progress' then
    raise exception 'operation cannot be completed from status %', v_operation.status;
  end if;

  update public.operations
  set
    status = 'completed',
    completed_at = now()
  where id = p_operation_id
  returning * into v_operation;

  update public.service_requests
  set status = 'completed'
  where id = v_operation.request_id;

  insert into public.operation_events (
    operation_id,
    event_type,
    actor_id,
    previous_status,
    new_status
  )
  values (p_operation_id, 'completed', auth.uid(), 'in_progress', 'completed');

  return v_operation;
end;
$$;


drop policy if exists "providers read compatible service requests"
  on public.service_requests;

create policy "providers read compatible service requests"
on public.service_requests
for select
using (
  exists (
    select 1
    from public.business_members bm
    where bm.user_id = auth.uid()
      and bm.status = 'active'
      and public.request_is_visible_to_business(service_requests.id, bm.business_id)
  )
);

grant execute on function public.find_matching_businesses_for_request(uuid)
to authenticated;
grant execute on function public.create_direct_service_request(uuid, uuid, uuid, text, text, text, date)
to authenticated;
grant execute on function public.provider_service_request_queue(uuid, text)
to authenticated;
grant execute on function public.provider_send_quote(uuid, uuid, text, integer, timestamptz)
to authenticated;
grant execute on function public.accept_quote(uuid)
to authenticated;
grant execute on function public.provider_start_operation(uuid)
to authenticated;
grant execute on function public.provider_complete_operation(uuid)
to authenticated;
