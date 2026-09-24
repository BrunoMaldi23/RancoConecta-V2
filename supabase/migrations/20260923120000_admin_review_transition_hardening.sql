-- ============================================================
-- RANCO CONECTA V2
-- Harden admin review transitions and canonical RPC names
-- ============================================================

create or replace function public.admin_business_review_queue(
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
  if auth.uid() is null or not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  return query
  select *
  from public.admin_list_business_reviews(
    p_status,
    p_business_type,
    p_search,
    p_limit,
    p_offset
  );
end;
$$;


create or replace function public.admin_business_review_detail(
  p_business_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  return public.admin_get_business_review(p_business_id);
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
  if auth.uid() is null or not public.current_user_is_admin() then
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

  if v_business.publication_status::text <> 'pending_review' then
    raise exception 'business can only request changes from pending_review';
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
  if auth.uid() is null or not public.current_user_is_admin() then
    raise exception 'not authorized';
  end if;

  select * into v_business
  from public.businesses
  where id = p_business_id
  for update;

  if not found then
    raise exception 'business not found';
  end if;

  if v_business.publication_status::text <> 'pending_review' then
    raise exception 'business can only be published from pending_review';
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
  if auth.uid() is null or not public.current_user_is_admin() then
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

  if v_business.publication_status::text <> 'published' then
    raise exception 'business can only be suspended from published';
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
  if auth.uid() is null or not public.current_user_is_admin() then
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

grant execute on function public.admin_business_review_queue(text, text, text, integer, integer)
to authenticated;
grant execute on function public.admin_business_review_detail(uuid)
to authenticated;
