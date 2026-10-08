-- Separate platform administration from tenant membership, preserve Auth
-- references to businesses, and reduce Data API privileges to policy-backed
-- operations. This is an additive forward migration; no historical file edits.

-- A deleted Auth identity must not cascade-delete its business/profile history.
do $$
declare
  v_owner_attnum smallint;
  v_profiles_attnum smallint;
  v_auth_attnum smallint;
  v_existing record;
  v_existing_found boolean;
begin
  select attnum into v_owner_attnum
  from pg_attribute
  where attrelid = 'public.businesses'::regclass
    and attname = 'owner_id' and not attisdropped;
  select attnum into v_profiles_attnum
  from pg_attribute
  where attrelid = 'public.profiles'::regclass
    and attname = 'id' and not attisdropped;
  select attnum into v_auth_attnum
  from pg_attribute
  where attrelid = 'auth.users'::regclass
    and attname = 'id' and not attisdropped;

  if v_owner_attnum is null or v_profiles_attnum is null
     or v_auth_attnum is null
     or (select atttypid from pg_attribute
         where attrelid = 'public.businesses'::regclass
           and attnum = v_owner_attnum) <> 'uuid'::regtype
     or (select atttypid from pg_attribute
         where attrelid = 'public.profiles'::regclass
           and attnum = v_profiles_attnum) <> 'uuid'::regtype then
    raise exception 'business owner FK preflight failed: expected UUID owner/profile IDs';
  end if;

  if exists (
    select 1 from public.businesses b
    left join public.profiles p on p.id = b.owner_id
    where p.id is null
  ) then
    raise exception 'business owner FK preflight failed: one or more owners have no profile';
  end if;

  select c.confrelid, c.confdeltype, c.confupdtype, c.conkey, c.confkey
  into v_existing
  from pg_constraint c
  where c.conrelid = 'public.businesses'::regclass
    and c.conname = 'businesses_owner_id_fkey'
    and c.contype = 'f';
  v_existing_found := found;

  if not (v_existing_found
     and v_existing.confrelid = 'public.profiles'::regclass
     and v_existing.confdeltype = 'r'
     and v_existing.confupdtype = 'a'
     and v_existing.conkey = array[v_owner_attnum]::smallint[]
     and v_existing.confkey = array[v_profiles_attnum]::smallint[]) then
    if v_existing_found then
      alter table public.businesses drop constraint businesses_owner_id_fkey;
    end if;
    alter table public.businesses
      add constraint businesses_owner_id_fkey
      foreign key (owner_id) references public.profiles(id)
      on delete restrict on update no action not valid;
    alter table public.businesses
      validate constraint businesses_owner_id_fkey;
  end if;
end;
$$;

create table if not exists public.super_admin_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete restrict,
  purpose text not null check (char_length(btrim(purpose)) between 12 and 400),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  ended_at timestamptz,
  constraint super_admin_sessions_expiry_check
    check (expires_at > started_at and expires_at <= started_at + interval '60 minutes')
);
create index if not exists super_admin_sessions_user_expiry_idx
  on public.super_admin_sessions(user_id, expires_at desc);
alter table public.super_admin_sessions enable row level security;
revoke all on public.super_admin_sessions from public, anon, authenticated;

create or replace function public.is_super_admin()
returns boolean
language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role::text = 'super_admin'
        and p.account_status::text = 'active'
    );
$$;
revoke all on function public.is_super_admin() from public, anon, authenticated;
grant execute on function public.is_super_admin() to authenticated, service_role;

create or replace function public.start_super_admin_session(
  p_purpose text,
  p_duration_minutes integer default 60
)
returns uuid
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_session_id uuid;
  v_purpose text := btrim(coalesce(p_purpose, ''));
  v_duration integer := coalesce(p_duration_minutes, 0);
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.is_super_admin() then
    raise exception 'super admin access required' using errcode = '42501';
  end if;
  if char_length(v_purpose) not between 12 and 400
     or v_duration not between 5 and 60 then
    raise exception 'INVALID_SUPER_ADMIN_SESSION' using errcode = '22023';
  end if;
  insert into public.super_admin_sessions(user_id, purpose, expires_at)
  values (auth.uid(), v_purpose, now() + make_interval(mins => v_duration))
  returning id into v_session_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, new_data)
  values (auth.uid(), 'super_admin_session_started', 'platform_admin_session',
    v_session_id, jsonb_build_object('purpose', v_purpose,
      'expires_at', now() + make_interval(mins => v_duration)));
  return v_session_id;
end;
$$;
revoke all on function public.start_super_admin_session(text, integer)
  from public, anon, authenticated, service_role;
grant execute on function public.start_super_admin_session(text, integer)
  to authenticated;

create or replace function public.end_super_admin_session()
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare v_session_id uuid;
begin
  if auth.uid() is null or not public.is_super_admin() then
    raise exception 'super admin access required' using errcode = '42501';
  end if;
  update public.super_admin_sessions
  set ended_at = now()
  where user_id = auth.uid() and ended_at is null and expires_at > now()
  returning id into v_session_id;
  if v_session_id is not null then
    insert into public.audit_logs(actor_id, action, entity_type, entity_id)
    values (auth.uid(), 'super_admin_session_ended',
      'platform_admin_session', v_session_id);
  end if;
end;
$$;
revoke all on function public.end_super_admin_session()
  from public, anon, authenticated, service_role;
grant execute on function public.end_super_admin_session() to authenticated;

create or replace function public.current_user_is_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select public.is_super_admin() and exists (
    select 1 from public.super_admin_sessions s
    where s.user_id = auth.uid() and s.ended_at is null
      and s.expires_at > now()
  );
$$;
revoke all on function public.current_user_is_admin()
  from public, anon, authenticated, service_role;
grant execute on function public.current_user_is_admin()
  to authenticated, service_role;

-- Legacy policy helper: anon must be able to evaluate it, but it is always false
-- without an authenticated SuperAdmin session.
create or replace function public.is_admin()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$ select public.current_user_is_admin(); $$;
revoke all on function public.is_admin() from public, anon, authenticated, service_role;
grant execute on function public.is_admin() to anon, authenticated, service_role;

create or replace function public.is_business_owner(p_business_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.profiles p
      where p.id = auth.uid() and p.account_status::text = 'active')
    and exists (
      select 1 from public.businesses b where b.id = p_business_id
        and (b.owner_id = auth.uid() or exists (
          select 1 from public.business_members bm
          where bm.business_id = b.id and bm.user_id = auth.uid()
            and bm.status = 'active' and bm.role = 'owner'
        ))
    );
$$;
revoke all on function public.is_business_owner(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.is_business_owner(uuid) to authenticated;

create or replace function public.is_business_admin(p_business_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.profiles p
      where p.id = auth.uid() and p.account_status::text = 'active')
    and exists (
      select 1 from public.businesses b where b.id = p_business_id
        and (b.owner_id = auth.uid() or exists (
          select 1 from public.business_members bm
          where bm.business_id = b.id and bm.user_id = auth.uid()
            and bm.status = 'active' and bm.role in ('owner', 'manager')
        ))
    );
$$;
revoke all on function public.is_business_admin(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.is_business_admin(uuid) to authenticated;

create or replace function public.user_can_manage_business(p_business_id uuid)
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$ select public.is_business_admin(p_business_id); $$;
revoke all on function public.user_can_manage_business(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.user_can_manage_business(uuid)
  to anon, authenticated, service_role;

create or replace function public.current_user_is_provider()
returns boolean language sql stable security definer
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and coalesce(auth.jwt() ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.profiles p
      where p.id = auth.uid() and p.account_status::text = 'active')
    and (
      exists (select 1 from public.profiles p
        where p.id = auth.uid() and p.role::text = 'provider')
      or exists (select 1 from public.businesses b where b.owner_id = auth.uid())
      or exists (select 1 from public.business_members bm
        where bm.user_id = auth.uid() and bm.status = 'active'
          and bm.role in ('owner', 'manager'))
    );
$$;
revoke all on function public.current_user_is_provider()
  from public, anon, authenticated, service_role;
grant execute on function public.current_user_is_provider()
  to authenticated, service_role;

-- Prevent direct clients from changing profile roles/status. The reconciliation
-- flag is only set inside the owner-only, one-shot role resolution function.
create or replace function public.protect_profile_privileged_fields()
returns trigger language plpgsql
set search_path = pg_catalog
as $$
declare
  v_trusted_write boolean := current_user = 'postgres'
    and (current_setting('ranco.admin_profile_write', true) = 'on'
      or current_setting('ranco.provider_role_reconciliation', true) = 'on');
begin
  if (new.role <> old.role or new.account_status <> old.account_status)
     and auth.role() is distinct from 'service_role' and not v_trusted_write then
    raise exception 'profile role and account status require a privileged server-side operation'
      using errcode = '42501';
  end if;
  if new.role <> 'provider' and old.role <> new.role
     and coalesce(current_setting('ranco.provider_role_reconciliation', true), 'off') <> 'on'
     and (exists (select 1 from public.businesses b where b.owner_id = old.id)
       or exists (select 1 from public.business_members bm
         where bm.user_id = old.id and bm.status = 'active'
           and bm.role in ('owner', 'manager'))) then
    raise exception 'PROVIDER_HAS_BUSINESS' using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function public.reconcile_provider_role_candidates()
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  r record;
  v_role text;
  v_resolution text;
  v_explicit_identity boolean;
begin
  for r in select c.* from public.provider_role_migration_candidates c
    where c.resolution is null for update loop
    select p.role::text into v_role
    from public.profiles p where p.id = r.profile_id for update;
    if not found then
      update public.provider_role_migration_candidates
      set resolution = 'MANUAL_REVIEW', resolved_at = now()
      where profile_id = r.profile_id;
      continue;
    end if;

    v_explicit_identity := r.provider_registration or r.has_published_business
      or exists (select 1 from public.audit_logs a
        where a.entity_type = 'profile' and a.entity_id = r.profile_id
          and a.action = 'provider_identity_registered'
          and a.created_at >= r.captured_at);
    if v_explicit_identity then
      v_resolution := 'DEBE_SER_PROVIDER';
    elsif r.has_onboarding_progress then
      v_resolution := 'AMBIGUO';
    else
      v_resolution := 'DEBE_SEGUIR_CUSTOMER';
    end if;

    if v_role not in ('customer', 'provider') then
      v_resolution := 'MANUAL_REVIEW';
    elsif v_resolution = 'DEBE_SER_PROVIDER' and v_role = 'customer' then
      perform set_config('ranco.provider_role_reconciliation', 'on', true);
      update public.profiles set role = 'provider' where id = r.profile_id;
      perform set_config('ranco.provider_role_reconciliation', 'off', true);
      insert into public.audit_logs(actor_id, action, entity_type, entity_id,
        old_data, new_data)
      values (null, 'provider_role_confirmed_by_evidence', 'profile', r.profile_id,
        jsonb_build_object('role', 'customer'),
        jsonb_build_object('role', 'provider', 'evidence', v_resolution));
    elsif v_resolution in ('AMBIGUO', 'DEBE_SEGUIR_CUSTOMER')
       and v_role = 'provider' then
      perform set_config('ranco.provider_role_reconciliation', 'on', true);
      update public.profiles set role = r.original_role::public.app_role
      where id = r.profile_id;
      perform set_config('ranco.provider_role_reconciliation', 'off', true);
      insert into public.audit_logs(actor_id, action, entity_type, entity_id,
        old_data, new_data)
      values (null, 'provider_role_legacy_promotion_reverted', 'profile', r.profile_id,
        jsonb_build_object('role', 'provider'),
        jsonb_build_object('role', r.original_role, 'resolution', v_resolution,
          'provider_registration', r.provider_registration,
          'published_business', r.has_published_business,
          'onboarding_progress', r.has_onboarding_progress));
    end if;

    update public.provider_role_migration_candidates
    set resolution = v_resolution, resolved_at = now()
    where profile_id = r.profile_id;
  end loop;
end;
$$;
revoke all on function public.reconcile_provider_role_candidates()
  from public, anon, authenticated, service_role;
select public.reconcile_provider_role_candidates();

-- Use role-scoped notification recipients. Tenant admins no longer receive
-- platform-global moderation or contact-message notifications.
create or replace function public.notify_admins_on_business_review()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
declare v_key text;
begin
  if new.publication_status = 'pending_review'
     and old.publication_status is distinct from 'pending_review' then
    v_key := case when old.publication_status = 'draft'
      then 'notify_new_business' else 'notify_business_changes' end;
    if coalesce((select value = 'true'::jsonb from public.system_settings
      where key = v_key), true) then
      insert into public.notifications
        (user_id, type, title, body, entity_type, entity_id, deep_link)
      select p.id,
        case when v_key = 'notify_new_business' then 'provider_pending_review'
          else 'provider_changes_review' end,
        case when v_key = 'notify_new_business'
          then 'Nuevo negocio pendiente de revisión'
          else 'Cambios de negocio pendientes de revisión' end,
        'Negocio pendiente: ' || new.name,
        'business', new.id, '/admin/businesses/' || new.id::text
      from public.profiles p
      where p.role::text = 'super_admin' and p.account_status::text = 'active'
      on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.notify_admins_on_contact_message()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if coalesce((select value = 'true'::jsonb from public.system_settings
    where key = 'notify_contact_message'), true) then
    insert into public.notifications
      (user_id, type, title, body, entity_type, entity_id)
    select p.id, 'contact_message', 'Nuevo mensaje de contacto',
      'Hay una nueva consulta para revisar.', 'contact_message', new.id
    from public.profiles p
    where p.role::text = 'super_admin' and p.account_status::text = 'active';
  end if;
  return new;
end;
$$;

-- Align table ACLs with permissive RLS operations. RLS restrictive session
-- policies do not create grants. No API role receives TRUNCATE/REFERENCES/TRIGGER.
alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated;
-- The service key is server-only. Keep its backend access working for the
-- validated Edge Functions (which perform contact, profile and audit writes).
grant all privileges on all tables in schema public to service_role;
grant usage, select on all sequences in schema public to service_role;
alter default privileges for role postgres in schema public
  grant all privileges on tables to service_role;
alter default privileges for role postgres in schema public
  grant usage, select on sequences to service_role;
do $$
declare
  t record;
  v_role text;
  v_role_oid oid;
  v_privilege text;
  v_policy_exists boolean;
begin
  for t in select c.oid, c.relname from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p') loop
    execute format('revoke all on table %s from public, anon, authenticated', t.oid::regclass);
    foreach v_role in array array['anon', 'authenticated'] loop
      select oid into v_role_oid from pg_roles where rolname = v_role;
      foreach v_privilege in array array['SELECT', 'INSERT', 'UPDATE', 'DELETE'] loop
        select exists (
          select 1 from pg_policy p
          where p.polrelid = t.oid and p.polpermissive
            and p.polcmd in (
              case v_privilege when 'SELECT' then 'r'
                when 'INSERT' then 'a' when 'UPDATE' then 'w' else 'd' end,
              '*'
            )
            and (0::oid = any(p.polroles) or v_role_oid = any(p.polroles))
        ) into v_policy_exists;
        if v_policy_exists and not (v_role = 'anon' and v_privilege <> 'SELECT') then
          execute format('grant %s on table %s to %I',
            v_privilege, t.oid::regclass, v_role);
        end if;
      end loop;
    end loop;
  end loop;
end;
$$;

-- Revoke PUBLIC/anon execution from every SECURITY DEFINER function, not only
-- admin_*; retain authenticated grants that existed explicitly/effectively and
-- allow only the small, reviewed anonymous helper surface.
do $$
declare
  r record;
  v_auth_exec boolean;
  v_anon_allow boolean;
begin
  for r in select p.oid, p.oid::regprocedure signature, p.proname,
      p.proconfig, owner.rolname owner_name
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    join pg_roles owner on owner.oid = p.proowner
    where n.nspname = 'public' and p.prosecdef loop
    if not exists (select 1 from unnest(coalesce(r.proconfig, array[]::text[])) c
      where c like 'search_path=%') then
      raise exception 'SECURITY DEFINER has no explicit search_path: %', r.signature;
    end if;
    if r.owner_name not in ('postgres', 'supabase_admin') then
      raise exception 'unexpected SECURITY DEFINER owner: % owned by %', r.signature, r.owner_name;
    end if;
    v_auth_exec := has_function_privilege('authenticated', r.oid, 'EXECUTE');
    v_anon_allow := r.signature::text in (
      'is_admin()',
      'user_can_manage_business(uuid)',
      'user_can_manage_business_path(text)',
      'record_business_analytics_event(uuid,text)',
      'reject_suspended_api_request()',
      'public_contact_channels()'
    );
    execute format('revoke execute on function %s from public, anon', r.signature);
    if v_auth_exec then
      execute format('grant execute on function %s to authenticated', r.signature);
    end if;
    if v_anon_allow then
      execute format('grant execute on function %s to anon', r.signature);
    end if;
  end loop;
end;
$$;

-- Keep Data API grants future-proof: every security-definer RPC must be
-- reviewed and explicitly granted to anon when a migration creates it.
