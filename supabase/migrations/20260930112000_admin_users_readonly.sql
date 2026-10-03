-- Read-only user directory for active administrators.
create or replace function public.admin_list_users(
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  full_name text,
  email text,
  role text,
  account_status text,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required';
  end if;

  return query
  select p.id, p.full_name, u.email::text, p.role::text,
    p.account_status::text, p.created_at, count(*) over ()
  from public.profiles p
  join auth.users u on u.id = p.id
  order by p.created_at desc, p.id desc
  limit least(greatest(p_limit, 1), 100)
  offset greatest(p_offset, 0);
end;
$$;

revoke all on function public.admin_list_users(integer, integer) from public;
grant execute on function public.admin_list_users(integer, integer)
to authenticated;
