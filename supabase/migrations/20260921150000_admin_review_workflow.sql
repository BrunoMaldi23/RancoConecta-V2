-- ============================================================
-- RANCO CONECTA V2
-- Admin review and publication workflow
-- ============================================================

alter type public.publication_status add value if not exists 'changes_requested';

create table if not exists public.business_review_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  event_type text not null,
  actor_id uuid references public.profiles(id) on delete set null,
  message text,
  previous_status text,
  new_status text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint business_review_events_type_check check (
    event_type in (
      'submitted',
      'resubmitted',
      'changes_requested',
      'rejected',
      'published',
      'suspended',
      'restored'
    )
  )
);

create index if not exists business_review_events_business_created_idx
  on public.business_review_events(business_id, created_at desc);

alter table public.business_review_events enable row level security;


create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.account_status = 'active'
      and p.role in ('admin', 'super_admin')
  );
$$;

grant execute on function public.current_user_is_admin()
to authenticated;

drop policy if exists "admins read business review events"
  on public.business_review_events;

create policy "admins read business review events"
on public.business_review_events
for select
using (public.current_user_is_admin());

drop policy if exists "business members read own review events"
  on public.business_review_events;

create policy "business members read own review events"
on public.business_review_events
for select
using (
  exists (
    select 1
    from public.business_members bm
    where bm.business_id = business_review_events.business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
);


create or replace function public.protect_business_sensitive_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if auth.role() <> 'service_role'
    and not public.current_user_is_admin()
    and (
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


create or replace function public.record_business_review_event(
  p_business_id uuid,
  p_event_type text,
  p_actor_id uuid,
  p_message text,
  p_previous_status text,
  p_new_status text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event_id uuid;
begin
  insert into public.business_review_events (
    business_id,
    event_type,
    actor_id,
    message,
    previous_status,
    new_status,
    metadata
  )
  values (
    p_business_id,
    p_event_type,
    p_actor_id,
    nullif(trim(coalesce(p_message, '')), ''),
    p_previous_status,
    p_new_status,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning id into v_event_id;

  insert into public.audit_logs (
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data,
    new_data
  )
  values (
    p_actor_id,
    'business_' || p_event_type,
    'business',
    p_business_id,
    jsonb_build_object('publication_status', p_previous_status),
    jsonb_build_object(
      'publication_status',
      p_new_status,
      'message',
      nullif(trim(coalesce(p_message, '')), ''),
      'metadata',
      coalesce(p_metadata, '{}'::jsonb)
    )
  );

  return v_event_id;
end;
$$;


create or replace function public.notify_business_managers(
  p_business_id uuid,
  p_type text,
  p_title text,
  p_body text
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id
  )
  select distinct
    bm.user_id,
    p_type,
    p_title,
    p_body,
    'business',
    p_business_id
  from public.business_members bm
  where bm.business_id = p_business_id
    and bm.status = 'active'
    and bm.role in ('owner', 'manager');
$$;


create or replace function public.admin_business_review_stats()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  select coalesce(jsonb_object_agg(status, count), '{}'::jsonb)
  into v_result
  from (
    select publication_status::text as status, count(*)::integer as count
    from public.businesses
    where publication_status::text in (
      'pending_review',
      'changes_requested',
      'published',
      'rejected',
      'suspended'
    )
    group by publication_status
  ) stats;

  return v_result;
end;
$$;


create or replace function public.admin_list_business_reviews(
  p_status text default 'pending_review',
  p_business_type text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  id uuid,
  name text,
  business_type text,
  publication_status text,
  verification_status text,
  category_name text,
  owner_name text,
  owner_email text,
  submitted_at timestamptz,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  return query
  with filtered as (
    select
      b.id,
      b.name,
      b.business_type::text as business_type,
      b.publication_status::text as publication_status,
      b.verification_status::text as verification_status,
      c.name as category_name,
      p.full_name as owner_name,
      u.email as owner_email,
      b.submitted_at,
      b.created_at,
      count(*) over() as total_count
    from public.businesses b
    left join public.categories c on c.id = b.primary_category_id
    left join public.profiles p on p.id = b.owner_id
    left join auth.users u on u.id = b.owner_id
    where (p_status is null or b.publication_status::text = p_status)
      and (p_business_type is null or b.business_type::text = p_business_type)
      and (
        p_search is null
        or b.name ilike '%' || p_search || '%'
        or coalesce(p.full_name, '') ilike '%' || p_search || '%'
        or coalesce(b.phone, '') ilike '%' || p_search || '%'
        or coalesce(b.whatsapp, '') ilike '%' || p_search || '%'
        or coalesce(b.email, '') ilike '%' || p_search || '%'
        or coalesce(u.email, '') ilike '%' || p_search || '%'
      )
    order by coalesce(b.submitted_at, b.created_at) desc
  )
  select *
  from filtered
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;


create or replace function public.admin_get_business_review(
  p_business_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_result jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  select jsonb_build_object(
    'business', to_jsonb(b),
    'category', to_jsonb(c),
    'owner', jsonb_build_object(
      'id', p.id,
      'full_name', p.full_name,
      'phone', p.phone,
      'email', u.email
    ),
    'coverage', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'location_id', l.id,
          'location_name', l.name,
          'commune_name', co.name
        )
      )
      from public.business_coverage bc
      join public.locations l on l.id = bc.location_id
      left join public.communes co on co.id = l.commune_id
      where bc.business_id = b.id
    ), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'subcategory_id', s.id,
          'subcategory_name', s.name,
          'description', bs.description,
          'price_from', bs.price_from
        )
      )
      from public.business_services bs
      join public.subcategories s on s.id = bs.subcategory_id
      where bs.business_id = b.id
        and bs.active
    ), '[]'::jsonb),
    'lodging_details', (
      select to_jsonb(ld)
      from public.lodging_details ld
      where ld.business_id = b.id
    ),
    'media', coalesce((
      select jsonb_agg(to_jsonb(bm) order by bm.sort_order, bm.created_at)
      from public.business_media bm
      where bm.business_id = b.id
    ), '[]'::jsonb),
    'requirements', coalesce((
      select jsonb_agg(to_jsonb(req))
      from public.business_review_requirements(b.id) req
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(to_jsonb(e) order by e.created_at desc)
      from public.business_review_events e
      where e.business_id = b.id
    ), '[]'::jsonb)
  )
  into v_result
  from public.businesses b
  left join public.categories c on c.id = b.primary_category_id
  left join public.profiles p on p.id = b.owner_id
  left join auth.users u on u.id = b.owner_id
  where b.id = p_business_id;

  if v_result is null then
    raise exception 'business not found';
  end if;

  return v_result;
end;
$$;


create or replace function public.admin_request_business_changes(
  p_business_id uuid,
  p_message text
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_previous text;
  v_message text := nullif(trim(coalesce(p_message, '')), '');
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  if v_message is null then
    raise exception 'message is required';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text not in ('pending_review', 'rejected') then
    raise exception 'business cannot request changes from status %', v_business.publication_status;
  end if;

  v_previous := v_business.publication_status::text;

  update public.businesses
  set
    publication_status = 'changes_requested',
    changes_requested_note = v_message
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    'changes_requested',
    auth.uid(),
    v_message,
    v_previous,
    'changes_requested'
  );

  perform public.notify_business_managers(
    p_business_id,
    'business_changes_requested',
    'Necesitamos algunos cambios',
    v_message
  );

  return v_business;
end;
$$;


create or replace function public.admin_reject_business(
  p_business_id uuid,
  p_reason text,
  p_can_resubmit boolean default false
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_previous text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text <> 'pending_review' then
    raise exception 'business can only be rejected from pending_review';
  end if;

  v_previous := v_business.publication_status::text;

  update public.businesses
  set
    publication_status = 'rejected',
    changes_requested_note = v_reason,
    onboarding_metadata = coalesce(onboarding_metadata, '{}'::jsonb)
      || jsonb_build_object('can_resubmit', coalesce(p_can_resubmit, false))
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    'rejected',
    auth.uid(),
    v_reason,
    v_previous,
    'rejected',
    jsonb_build_object('can_resubmit', coalesce(p_can_resubmit, false))
  );

  perform public.notify_business_managers(
    p_business_id,
    'business_rejected',
    'Tu negocio fue rechazado',
    v_reason
  );

  return v_business;
end;
$$;


create or replace function public.admin_publish_business(
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
  v_previous text;
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text not in ('pending_review', 'changes_requested') then
    raise exception 'business cannot be published from status %', v_business.publication_status;
  end if;

  select string_agg(requirement_key, ', ')
  into v_missing
  from public.business_review_requirements(p_business_id)
  where not satisfied;

  if v_missing is not null then
    raise exception 'missing requirements: %', v_missing;
  end if;

  v_previous := v_business.publication_status::text;

  update public.businesses
  set publication_status = 'published'
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    'published',
    auth.uid(),
    'Negocio aprobado y publicado.',
    v_previous,
    'published'
  );

  perform public.notify_business_managers(
    p_business_id,
    'business_published',
    'Tu negocio fue publicado',
    'Tu negocio ya está visible en Ranco Conecta.'
  );

  return v_business;
end;
$$;


create or replace function public.admin_suspend_business(
  p_business_id uuid,
  p_reason text
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
  v_previous text;
  v_reason text := nullif(trim(coalesce(p_reason, '')), '');
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text = 'suspended' then
    raise exception 'business is already suspended';
  end if;

  v_previous := v_business.publication_status::text;

  update public.businesses
  set
    publication_status = 'suspended',
    changes_requested_note = v_reason,
    onboarding_metadata = coalesce(onboarding_metadata, '{}'::jsonb)
      || jsonb_build_object('pre_suspension_status', v_previous)
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    'suspended',
    auth.uid(),
    v_reason,
    v_previous,
    'suspended'
  );

  perform public.notify_business_managers(
    p_business_id,
    'business_suspended',
    'Tu negocio fue suspendido',
    v_reason
  );

  return v_business;
end;
$$;


create or replace function public.admin_restore_business(
  p_business_id uuid
)
returns public.businesses
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_business public.businesses%rowtype;
begin
  if not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text <> 'suspended' then
    raise exception 'business is not suspended';
  end if;

  update public.businesses
  set publication_status = 'published'
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    'restored',
    auth.uid(),
    'Negocio restaurado.',
    'suspended',
    'published'
  );

  perform public.notify_business_managers(
    p_business_id,
    'business_restored',
    'Tu negocio fue restaurado',
    'Tu negocio vuelve a estar publicado.'
  );

  return v_business;
end;
$$;


grant execute on function public.admin_business_review_stats()
to authenticated;
grant execute on function public.admin_list_business_reviews(text, text, text, integer, integer)
to authenticated;
grant execute on function public.admin_get_business_review(uuid)
to authenticated;
grant execute on function public.admin_request_business_changes(uuid, text)
to authenticated;
grant execute on function public.admin_reject_business(uuid, text, boolean)
to authenticated;
grant execute on function public.admin_publish_business(uuid)
to authenticated;
grant execute on function public.admin_suspend_business(uuid, text)
to authenticated;
grant execute on function public.admin_restore_business(uuid)
to authenticated;


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
  v_previous text;
  v_event_type text;
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

  v_previous := v_business.publication_status::text;
  v_event_type := case
    when v_previous = 'changes_requested' then 'resubmitted'
    else 'submitted'
  end;

  update public.businesses
  set
    publication_status = 'pending_review',
    submitted_at = now(),
    changes_requested_note = null
  where id = p_business_id
  returning * into v_business;

  perform public.record_business_review_event(
    p_business_id,
    v_event_type,
    auth.uid(),
    'Negocio enviado a revisión.',
    v_previous,
    'pending_review'
  );

  return v_business;
end;
$$;

grant execute on function public.submit_business_for_review(uuid)
to authenticated;

-- ============================================================
-- END
-- ============================================================
