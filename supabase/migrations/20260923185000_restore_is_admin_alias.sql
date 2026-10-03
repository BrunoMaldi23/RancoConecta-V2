-- Older conversation and notification migrations depend on this helper.
-- Route it to the canonical active-admin check defined on 20260921.
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public, auth
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and public.current_user_is_admin();
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
