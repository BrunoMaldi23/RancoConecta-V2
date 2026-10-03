-- Final definition after the historical alias and the admin directory RPC.
-- Anon must be able to evaluate policies that call is_admin(); the result is
-- always false without a legitimate active administrator identity.
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid()
        and p.account_status = 'active'
        and p.role in ('admin', 'super_admin')
    );
$$;

revoke all on function public.is_admin() from public, anon, authenticated, service_role;
grant execute on function public.is_admin() to anon, authenticated, service_role;

-- Preserve the 3.17 response contract while bounding work and avoiding
-- integer overflow for page offsets. The search remains parameterized.
create or replace function public.admin_search_users(
  p_page integer default 1,
  p_page_size integer default 50,
  p_search text default null,
  p_role text default null
)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog
as $$
declare
  v_total bigint;
  v_rows jsonb;
  v_search text;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_page is null or p_page not between 1 and 10000
     or p_page_size is null or p_page_size not in (10, 20, 50)
     or (p_role is not null and p_role not in ('CUSTOMER', 'PROVIDER', 'ADMIN', 'VISITOR'))
     or (p_search is not null and char_length(p_search) > 100) then
    raise exception 'INVALID_USER_PAGE' using errcode = '22023';
  end if;
  v_search := nullif(btrim(p_search), '');

  select count(*) into v_total
  from public.profiles p join auth.users u on u.id = p.id
  where (p_role is null or
    (p_role = 'ADMIN' and p.role::text in ('admin', 'super_admin')) or
    (p_role = 'VISITOR' and u.is_anonymous) or
    (p_role = 'CUSTOMER' and p.role::text = 'customer' and not u.is_anonymous) or
    (p_role = 'PROVIDER' and p.role::text = 'provider'))
    and (v_search is null
      or p.full_name ilike '%' || v_search || '%'
      or u.email ilike '%' || v_search || '%');

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
      and (v_search is null
        or p.full_name ilike '%' || v_search || '%'
        or u.email ilike '%' || v_search || '%')
    order by p.created_at desc, p.id desc
    limit p_page_size offset (p_page - 1)::bigint * p_page_size
  ) r;
  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;

revoke all on function public.admin_search_users(integer, integer, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.admin_search_users(integer, integer, text, text)
to authenticated;
