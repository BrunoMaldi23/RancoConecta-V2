-- A previously issued JWT remains valid after account_status changes.
-- This database check uses the current profile row on every request.
create or replace function public.account_session_allowed()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is null or exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.account_status = 'active'
  );
$$;

revoke all on function public.account_session_allowed()
from public, anon, authenticated, service_role;
grant execute on function public.account_session_allowed()
to anon, authenticated, service_role;

create or replace function public.reject_suspended_api_request()
returns void
language plpgsql stable security definer
set search_path = pg_catalog
as $$
begin
  if not public.account_session_allowed() then
    raise exception 'ACCOUNT_SUSPENDED' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.reject_suspended_api_request()
from public, anon, authenticated, service_role;
grant execute on function public.reject_suspended_api_request()
to authenticator;

-- PostgREST runs this before every Data API / RPC request, including
-- SECURITY DEFINER RPCs. RLS below also covers direct table access.
alter role authenticator
set pgrst.db_pre_request = 'public.reject_suspended_api_request';

do $$
declare r record;
begin
  for r in
    select c.relname
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
  loop
    execute format('drop policy if exists "account session allowed" on public.%I', r.relname);
    execute format(
      'create policy "account session allowed" on public.%I as restrictive for all to authenticated using (public.account_session_allowed()) with check (public.account_session_allowed())',
      r.relname
    );
  end loop;
end;
$$;

drop policy if exists "account session allowed" on storage.objects;
create policy "account session allowed"
on storage.objects as restrictive for all to authenticated
using (public.account_session_allowed())
with check (public.account_session_allowed());
