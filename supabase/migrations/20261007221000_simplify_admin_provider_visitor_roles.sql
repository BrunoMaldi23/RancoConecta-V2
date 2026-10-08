-- Final account model: global admin, provider, and public anon visitors.
-- Historical customer identities remain stored as blocked legacy profiles.
begin;

do $$
begin
  if to_regclass('public.profiles') is null
     or to_regclass('public.businesses') is null then
    raise exception 'role transition requires profiles and businesses';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = 'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid
  ) then
    raise exception 'confirmed initial admin profile is missing; abort role transition';
  end if;
end;
$$;

-- Account creation never creates a consumer profile. Provider onboarding may
-- complete its own pending provider profile; anonymous visitors have no profile.
alter table public.profiles alter column role set default 'provider';
alter table public.profiles alter column account_status set default 'active';
alter table public.profiles drop constraint if exists profiles_role_check;

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if coalesce(new.is_anonymous, false) then
    return new;
  end if;
  insert into public.profiles (id, full_name, role, account_status)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), ''),
    'provider'::public.app_role,
    'active'::public.account_status
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Preserve identity and related rows. Only the explicitly confirmed account
-- and previously global super_admin profiles become global admin. Historical
-- ambiguous tenant admins lose global access: business owners retain provider
-- scope; other accounts are retained as blocked legacy profiles for review.
create temporary table _role_transition_audit on commit drop as
select id, role::text as old_role, account_status::text as old_status,
       case
         when id = 'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid
              or role::text = 'super_admin' then 'admin'
         when role::text = 'admin' and exists (
           select 1 from public.businesses b where b.owner_id = profiles.id
         ) then 'provider'
         when role::text = 'admin' then 'legacy_customer'
         when role::text = 'customer' then 'legacy_customer'
         else role::text
       end as new_role,
       case
         when id = 'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid then 'active'
         when role::text = 'customer' then 'suspended'
         when role::text = 'admin' and not exists (
           select 1 from public.businesses b where b.owner_id = profiles.id
         ) then 'suspended'
         else account_status::text
       end as new_status
from public.profiles;

-- Use the existing privileged-write guard's transaction-local bypass only for
-- this controlled migration. The Auth identities and profile IDs are retained.
select set_config('ranco.admin_profile_write', 'on', true);
select set_config('ranco.provider_role_reconciliation', 'on', true);
update public.profiles p
set role = a.new_role::public.app_role,
    account_status = a.new_status::public.account_status
from _role_transition_audit a
where p.id = a.id
  and (p.role::text <> a.new_role or p.account_status::text <> a.new_status);
select set_config('ranco.admin_profile_write', 'off', true);
select set_config('ranco.provider_role_reconciliation', 'off', true);

alter table public.profiles add constraint profiles_role_check
  check (role in ('admin', 'provider', 'legacy_customer'));

insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_data, new_data)
select null, 'role_model_transition', 'profile', id,
       jsonb_build_object('role', old_role, 'account_status', old_status),
       jsonb_build_object('role', new_role, 'account_status', new_status)
from _role_transition_audit
where old_role <> new_role or old_status <> new_status;

-- One meaning everywhere: only an active profile with role=admin is global.
create or replace function public.current_user_is_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null and exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role::text = 'admin'
      and p.account_status = 'active'
  );
$$;
revoke all on function public.current_user_is_admin() from public, anon;
grant execute on function public.current_user_is_admin() to authenticated, service_role;

-- Compatibility helper for old callers during rollout. It has no separate
-- SuperAdmin/session semantics and is retired from application code.
create or replace function public.is_super_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$ select public.current_user_is_admin(); $$;
revoke all on function public.is_super_admin() from public, anon;
grant execute on function public.is_super_admin() to authenticated, service_role;
revoke all on function public.start_super_admin_session(text, integer)
  from public, anon, authenticated, service_role;
revoke all on function public.end_super_admin_session()
  from public, anon, authenticated, service_role;

-- The account directory contains only provider and administrator accounts.
create or replace function public.admin_search_users(
  p_page integer,
  p_page_size integer,
  p_search text,
  p_role text,
  p_status text
)
returns jsonb language plpgsql stable security definer
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
     or (p_role is not null and p_role not in ('ADMIN', 'PROVIDER'))
     or (p_status is not null and p_status not in ('active', 'pending', 'suspended', 'blocked', 'deleted'))
     or (p_search is not null and char_length(p_search) > 100) then
    raise exception 'INVALID_USER_PAGE' using errcode = '22023';
  end if;
  v_search := nullif(btrim(p_search), '');
  select count(*) into v_total
  from public.profiles p join auth.users u on u.id = p.id
  where p.role::text in ('admin', 'provider')
    and (p_status is null or p.account_status::text = p_status)
    and (p_role is null or p.role::text = lower(p_role))
    and (v_search is null or p.full_name ilike '%' || v_search || '%'
      or u.email ilike '%' || v_search || '%');
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id desc), '[]'::jsonb)
    into v_rows
  from (
    select p.id, p.full_name, u.email::text, p.role::text as role,
      p.account_status::text as account_status, p.created_at,
      false as is_anonymous
    from public.profiles p join auth.users u on u.id = p.id
    where p.role::text in ('admin', 'provider')
      and (p_status is null or p.account_status::text = p_status)
      and (p_role is null or p.role::text = lower(p_role))
      and (v_search is null or p.full_name ilike '%' || v_search || '%'
        or u.email ilike '%' || v_search || '%')
    order by p.created_at desc, p.id desc
    limit p_page_size offset (p_page - 1)::bigint * p_page_size
  ) r;
  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;
revoke all on function public.admin_search_users(integer, integer, text, text, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_search_users(integer, integer, text, text, text)
  to authenticated;

create or replace function public.admin_change_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_old_role public.app_role;
  v_status text;
  v_new_role public.app_role;
begin
  if v_actor is null or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_user_id is null or p_role not in ('provider', 'admin') then
    raise exception 'INVALID_ROLE_CHANGE' using errcode = '22023';
  end if;
  v_new_role := p_role::public.app_role;
  perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
  select role, account_status into v_old_role, v_status
  from public.profiles where id = p_user_id for update;
  if not found then raise exception 'USER_NOT_FOUND' using errcode = '22023'; end if;
  if v_status in ('blocked', 'deleted', 'disabled')
     or v_old_role::text not in ('admin', 'provider') then
    raise exception 'ROLE_CHANGE_NOT_ALLOWED' using errcode = '42501';
  end if;
  if v_old_role = v_new_role then return; end if;
  if v_old_role::text = 'admin' and v_new_role::text <> 'admin'
     and (select count(*) from public.profiles
          where role::text = 'admin' and account_status = 'active') <= 1 then
    raise exception 'LAST_ADMIN' using errcode = '23514';
  end if;
  if v_new_role::text = 'admin' and v_status <> 'active' then
    raise exception 'ADMIN_MUST_BE_ACTIVE' using errcode = '23514';
  end if;
  perform set_config('ranco.admin_profile_write', 'on', true);
  update public.profiles set role = v_new_role where id = p_user_id;
  perform set_config('ranco.admin_profile_write', 'off', true);
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_data, new_data)
  values (v_actor, 'user_role_changed', 'profile', p_user_id,
    jsonb_build_object('role', v_old_role::text),
    jsonb_build_object('role', v_new_role::text));
end;
$$;
revoke all on function public.admin_change_user_role(uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_change_user_role(uuid, text)
  to authenticated;

-- Remove consumer-specific access to requests. Admins and providers retain
-- their scoped read paths; visitors will receive a dedicated safe submit path
-- in the request-contract migration before production apply.
drop policy if exists "account session allowed" on public.service_requests;
drop policy if exists service_requests_customer_insert on public.service_requests;
drop policy if exists service_requests_participants_read on public.service_requests;
drop policy if exists service_requests_participants_update on public.service_requests;
create policy service_requests_admin_read on public.service_requests
  for select to authenticated using (public.current_user_is_admin());

revoke execute on function public.create_direct_service_request(
  uuid, uuid, uuid, text, text, text, date, uuid
) from public, anon, authenticated;

-- Enforce the two account roles and protect the last active administrator
-- regardless of whether a mutation came through UI, RPC, or service backend.
create or replace function public.enforce_final_profile_roles()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_migration_write boolean := current_user = 'postgres'
    and current_setting('ranco.admin_profile_write', true) = 'on';
begin
  if tg_op = 'DELETE' then
    if old.role::text = 'admin' and old.account_status = 'active'
       and not v_migration_write then
      perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
      if (select count(*) from public.profiles
          where role::text = 'admin' and account_status = 'active') <= 1 then
        raise exception 'LAST_ADMIN' using errcode = '23514';
      end if;
    end if;
    return old;
  end if;

  if new.role::text in ('customer', 'super_admin') and not v_migration_write then
    raise exception 'ROLE_NOT_ALLOWED: use admin, provider, or retained legacy_customer'
      using errcode = '23514';
  end if;

  if old.role::text = 'admin' and old.account_status = 'active'
     and (new.role::text <> 'admin' or new.account_status <> 'active')
     and not v_migration_write then
    perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
    if (select count(*) from public.profiles
        where role::text = 'admin' and account_status = 'active') <= 1 then
      raise exception 'LAST_ADMIN' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_enforce_final_roles on public.profiles;
create trigger profiles_enforce_final_roles
before insert or update or delete on public.profiles
for each row execute function public.enforce_final_profile_roles();
revoke all on function public.enforce_final_profile_roles() from public, anon, authenticated;

-- The migration must leave exactly one active global admin and it must be the
-- human-confirmed identity. No ambiguous legacy admin is promoted by inference.
do $$
begin
  if (select count(*) from public.profiles
      where role::text = 'admin' and account_status = 'active') < 1 then
    raise exception 'role transition left no active admin';
  end if;
  if not exists (select 1 from public.profiles
      where id = 'a7affb25-ad32-4836-be38-cb2af81343c7'::uuid
        and role::text = 'admin' and account_status = 'active') then
    raise exception 'confirmed initial admin is not active admin';
  end if;
end;
$$;

commit;
