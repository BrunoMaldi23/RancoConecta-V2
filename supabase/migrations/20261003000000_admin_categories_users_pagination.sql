-- Admin category operations and filtered user directory. Existing public catalog
-- policies remain active; only administrators can see inactive categories.
create policy "admin read all categories" on public.categories
  for select to authenticated using (
    coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and public.current_user_is_admin()
  );

-- Subcategories of a deactivated category must also leave public discovery.
drop policy if exists "public read active subcategories" on public.subcategories;
create policy "public read active subcategories" on public.subcategories
  for select using (active and exists (
    select 1 from public.categories c
    where c.id = subcategories.category_id and c.active
  ));

create or replace function public.admin_list_categories()
returns setof public.categories
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  return query select c.* from public.categories c order by c.sort_order, c.name;
end;
$$;

-- The legacy business queue embeds total_count only in returned rows. This
-- wrapper preserves the total on an empty last page without loading all rows.
create or replace function public.admin_search_business_reviews(
  p_status text default 'pending_review',
  p_business_type text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare v_rows jsonb; v_total bigint;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(to_jsonb(r) order by coalesce(r.submitted_at, r.created_at) desc),
    '[]'::jsonb), max(r.total_count)
  into v_rows, v_total
  from public.admin_list_business_reviews(
    p_status, p_business_type, p_search, p_limit, p_offset) r;
  if v_total is null then
    select r.total_count into v_total
    from public.admin_list_business_reviews(
      p_status, p_business_type, p_search, 1, 0) r;
  end if;
  return jsonb_build_object('rows', v_rows, 'total_count', coalesce(v_total, 0));
end;
$$;

revoke all on function public.admin_search_business_reviews(text, text, text, integer, integer)
from public, anon;
grant execute on function public.admin_search_business_reviews(text, text, text, integer, integer)
to authenticated;

create or replace function public.admin_upsert_category(
  p_id uuid, p_name text, p_slug text, p_active boolean
)
returns public.categories
language plpgsql security definer
set search_path = public, auth
as $$
declare v_category public.categories;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_name is null or length(btrim(p_name)) = 0 or length(btrim(p_name)) > 120 then
    raise exception 'CATEGORY_NAME_INVALID' using errcode = '22023';
  end if;
  if p_slug is null or length(p_slug) > 120
     or p_slug !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
    raise exception 'CATEGORY_SLUG_INVALID' using errcode = '22023';
  end if;
  if p_active is null then
    raise exception 'CATEGORY_ACTIVE_INVALID' using errcode = '22023';
  end if;
  if p_id is null then
    insert into public.categories (name, slug, icon_key, theme_key, active)
    values (btrim(p_name), p_slug, 'category', 'forest', p_active)
    returning * into v_category;
  else
    update public.categories
    set name = btrim(p_name), slug = p_slug, active = p_active
    where id = p_id returning * into v_category;
    if not found then
      raise exception 'CATEGORY_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;
  return v_category;
exception
  when unique_violation then
    raise exception 'CATEGORY_SLUG_DUPLICATE' using errcode = '23505';
end;
$$;

create or replace function public.admin_delete_category(p_id uuid)
returns void
language plpgsql security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  perform 1 from public.categories where id = p_id for update;
  if not found then
    raise exception 'CATEGORY_NOT_FOUND' using errcode = 'P0002';
  end if;
  if exists(select 1 from public.subcategories where category_id = p_id)
     or exists(select 1 from public.businesses where primary_category_id = p_id)
     or exists(select 1 from public.service_requests where category_id = p_id) then
    raise exception 'CATEGORY_IN_USE' using errcode = '23503';
  end if;
  delete from public.categories where id = p_id;
exception
  when foreign_key_violation then
    raise exception 'CATEGORY_IN_USE' using errcode = '23503';
end;
$$;

revoke all on function public.admin_list_categories() from public, anon;
revoke all on function public.admin_upsert_category(uuid, text, text, boolean) from public, anon;
revoke all on function public.admin_delete_category(uuid) from public, anon;
grant execute on function public.admin_list_categories() to authenticated;
grant execute on function public.admin_upsert_category(uuid, text, text, boolean) to authenticated;
grant execute on function public.admin_delete_category(uuid) to authenticated;

-- Preserve the original two-argument RPC for older clients.
create or replace function public.admin_search_users(
  p_page integer default 1,
  p_page_size integer default 50,
  p_search text default null,
  p_role text default null
)
returns jsonb
language plpgsql stable security definer
set search_path = public, auth
as $$
declare v_total bigint; v_rows jsonb;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_page is null or p_page < 1 or p_page_size is null
     or p_page_size not in (10, 20, 50)
     or (p_role is not null and p_role not in ('CUSTOMER', 'PROVIDER', 'ADMIN', 'VISITOR')) then
    raise exception 'INVALID_USER_PAGE' using errcode = '22023';
  end if;
  select count(*) into v_total
  from public.profiles p join auth.users u on u.id = p.id
  where (p_role is null or
    (p_role = 'ADMIN' and p.role::text in ('admin', 'super_admin')) or
    (p_role = 'VISITOR' and u.is_anonymous) or
    (p_role = 'CUSTOMER' and p.role::text = 'customer' and not u.is_anonymous) or
    (p_role = 'PROVIDER' and p.role::text = 'provider'))
    and (nullif(btrim(p_search), '') is null
      or p.full_name ilike '%' || btrim(p_search) || '%'
      or u.email ilike '%' || btrim(p_search) || '%');
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id desc), '[]'::jsonb)
    into v_rows
  from (
    select p.id, p.full_name, u.email::text, p.role::text as role,
      p.account_status::text as account_status, p.created_at,
      coalesce(u.is_anonymous, false) as is_anonymous
    from public.profiles p join auth.users u on u.id = p.id
    where (p_role is null or
      (p_role = 'ADMIN' and p.role::text in ('admin', 'super_admin')) or
      (p_role = 'VISITOR' and u.is_anonymous) or
      (p_role = 'CUSTOMER' and p.role::text = 'customer' and not u.is_anonymous) or
      (p_role = 'PROVIDER' and p.role::text = 'provider'))
      and (nullif(btrim(p_search), '') is null
        or p.full_name ilike '%' || btrim(p_search) || '%'
        or u.email ilike '%' || btrim(p_search) || '%')
    order by p.created_at desc, p.id desc
    limit p_page_size offset (p_page - 1) * p_page_size
  ) r;
  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;

revoke all on function public.admin_search_users(integer, integer, text, text) from public, anon;
grant execute on function public.admin_search_users(integer, integer, text, text) to authenticated;

-- Retain the previous client contract while applying the same explicit gate.
create or replace function public.admin_list_users(
  p_limit integer default 50, p_offset integer default 0
)
returns table (
  id uuid, full_name text, email text, role text, account_status text,
  created_at timestamptz, total_count bigint
)
language plpgsql stable security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  return query
  select p.id, p.full_name, u.email::text, p.role::text,
    p.account_status::text, p.created_at, count(*) over ()
  from public.profiles p join auth.users u on u.id = p.id
  order by p.created_at desc, p.id desc
  limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
end;
$$;
