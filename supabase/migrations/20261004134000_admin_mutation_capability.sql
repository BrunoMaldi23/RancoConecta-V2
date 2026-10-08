create or replace function public.admin_user_mutations_ready()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select public.current_user_is_admin();
$$;

revoke all on function public.admin_user_mutations_ready()
from public, anon, authenticated, service_role;
grant execute on function public.admin_user_mutations_ready()
to authenticated;
