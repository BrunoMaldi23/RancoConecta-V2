-- Keep the admin review result contract aligned with auth.users.email,
-- which is varchar(255). PL/pgSQL RETURN QUERY requires an exact text type.
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
  if auth.uid() is null or not public.current_user_is_admin() then
    raise exception 'not authorized' using errcode = '42501';
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
      u.email::text as owner_email,
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
  select * from filtered
  limit greatest(1, least(coalesce(p_limit, 20), 100))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

revoke all on function public.admin_list_business_reviews(text, text, text, integer, integer)
from public, anon;
grant execute on function public.admin_list_business_reviews(text, text, text, integer, integer)
to authenticated;
