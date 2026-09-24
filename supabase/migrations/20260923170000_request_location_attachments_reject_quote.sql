-- ============================================================
-- RANCO CONECTA V2
-- Request locations, attachments, location-aware matching, quote rejection
-- ============================================================

alter table public.service_requests
  add column if not exists location_id uuid references public.locations(id) on delete restrict;

create index if not exists service_requests_location_status_idx
  on public.service_requests(location_id, status);


create table if not exists public.request_attachments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  uploader_user_id uuid not null references public.profiles(id) on delete restrict,
  storage_path text not null unique,
  file_name text not null,
  mime_type text not null,
  size_bytes integer not null,
  created_at timestamptz not null default now(),
  constraint request_attachments_size_check check (
    size_bytes > 0 and size_bytes <= 10485760
  ),
  constraint request_attachments_mime_check check (
    mime_type in (
      'image/jpeg',
      'image/png',
      'image/webp',
      'application/pdf'
    )
  )
);

create index if not exists request_attachments_request_created_idx
  on public.request_attachments(request_id, created_at);

alter table public.request_attachments enable row level security;

insert into storage.buckets (id, name, public)
values ('request-attachments', 'request-attachments', false)
on conflict (id) do update set public = false;


create or replace function public.user_can_access_service_request(
  p_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.service_requests sr
    where sr.id = p_request_id
      and (
        sr.customer_id = auth.uid()
        or public.current_user_is_admin()
        or exists (
          select 1
          from public.business_members bm
          where bm.user_id = auth.uid()
            and bm.status = 'active'
            and (
              bm.business_id = sr.business_id
              or public.request_is_visible_to_business(sr.id, bm.business_id)
            )
        )
      )
  );
$$;


create or replace function public.user_can_upload_request_attachment(
  p_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.service_requests sr
    where sr.id = p_request_id
      and (
        sr.customer_id = auth.uid()
        or exists (
          select 1
          from public.operations o
          join public.business_members bm on bm.business_id = o.business_id
          where o.request_id = sr.id
            and bm.user_id = auth.uid()
            and bm.status = 'active'
            and bm.role in ('owner', 'manager')
        )
      )
  );
$$;


create or replace function public.request_attachment_path_request_id(
  p_path text
)
returns uuid
language plpgsql
stable
security definer
set search_path = public, storage
as $$
declare
  v_request_id uuid;
begin
  if (storage.foldername(p_path))[1] <> 'requests' then
    return null;
  end if;

  v_request_id := (storage.foldername(p_path))[2]::uuid;
  return v_request_id;
exception
  when others then
    return null;
end;
$$;


drop policy if exists "request participants read attachments"
  on public.request_attachments;

create policy "request participants read attachments"
on public.request_attachments
for select
using (public.user_can_access_service_request(request_id));

drop policy if exists "request participants create attachments"
  on public.request_attachments;

create policy "request participants create attachments"
on public.request_attachments
for insert
with check (
  uploader_user_id = auth.uid()
  and public.user_can_upload_request_attachment(request_id)
);

drop policy if exists "request uploaders delete attachments"
  on public.request_attachments;

create policy "request uploaders delete attachments"
on public.request_attachments
for delete
using (
  uploader_user_id = auth.uid()
  and public.user_can_upload_request_attachment(request_id)
);


drop policy if exists "request participants read request attachments objects"
  on storage.objects;

create policy "request participants read request attachments objects"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'request-attachments'
  and public.user_can_access_service_request(
    public.request_attachment_path_request_id(name)
  )
);

drop policy if exists "request participants upload request attachments objects"
  on storage.objects;

create policy "request participants upload request attachments objects"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'request-attachments'
  and public.user_can_upload_request_attachment(
    public.request_attachment_path_request_id(name)
  )
);

drop policy if exists "request uploaders delete request attachments objects"
  on storage.objects;

create policy "request uploaders delete request attachments objects"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'request-attachments'
  and public.user_can_upload_request_attachment(
    public.request_attachment_path_request_id(name)
  )
);


create or replace function public.create_direct_service_request(
  p_business_id uuid,
  p_category_id uuid,
  p_subcategory_id uuid,
  p_description text,
  p_address_text text,
  p_urgency text default 'normal',
  p_desired_date date default null,
  p_location_id uuid default null
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

  if v_urgency not in ('low', 'normal', 'high', 'urgent') then
    raise exception 'invalid urgency';
  end if;

  if p_location_id is not null and not exists (
    select 1 from public.locations l where l.id = p_location_id and l.active
  ) then
    raise exception 'location is not available';
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

  if p_location_id is not null and not exists (
    select 1
    from public.business_coverage bc
    where bc.business_id = p_business_id
      and bc.location_id = p_location_id
  ) then
    raise exception 'business does not cover this location';
  end if;

  insert into public.service_requests (
    customer_id,
    business_id,
    category_id,
    subcategory_id,
    location_id,
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
    p_location_id,
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
          and (
            sr.location_id is null
            or exists (
              select 1
              from public.business_coverage bc
              where bc.business_id = b.id
                and bc.location_id = sr.location_id
            )
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
      when v_request.location_id is null then 'subcategory_legacy_location'
      else 'subcategory_and_location'
    end
  from public.businesses b
  join public.business_services bs
    on bs.business_id = b.id
   and bs.subcategory_id = v_request.subcategory_id
   and bs.active
  left join public.categories c on c.id = b.primary_category_id
  where b.publication_status = 'published'
    and (v_request.business_id is null or b.id = v_request.business_id)
    and (
      v_request.location_id is null
      or exists (
        select 1
        from public.business_coverage bc
        where bc.business_id = b.id
          and bc.location_id = v_request.location_id
      )
    )
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
  location_id uuid,
  location_name text,
  description text,
  address_text text,
  urgency text,
  desired_date date,
  request_status text,
  attachment_count integer,
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
    sr.location_id,
    l.name,
    sr.description,
    sr.address_text,
    sr.urgency::text,
    sr.desired_date,
    sr.status::text,
    (
      select count(*)::integer
      from public.request_attachments ra
      where ra.request_id = sr.id
    ),
    q.id,
    q.status::text,
    q.total_amount,
    o.id,
    o.status,
    sr.created_at
  from public.service_requests sr
  join public.subcategories s on s.id = sr.subcategory_id
  left join public.locations l on l.id = sr.location_id
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


create or replace function public.reject_quote(
  p_quote_id uuid
)
returns public.quotes
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quote public.quotes%rowtype;
  v_request public.service_requests%rowtype;
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

  if v_quote.status::text = 'rejected' then
    return v_quote;
  end if;

  if v_quote.status::text <> 'pending' then
    raise exception 'quote already responded';
  end if;

  update public.quotes
  set status = 'rejected'
  where id = p_quote_id
  returning * into v_quote;

  return v_quote;
end;
$$;

grant execute on function public.create_direct_service_request(uuid, uuid, uuid, text, text, text, date, uuid)
to authenticated;
grant execute on function public.reject_quote(uuid)
to authenticated;
grant select, insert, delete
on public.request_attachments
to authenticated;
