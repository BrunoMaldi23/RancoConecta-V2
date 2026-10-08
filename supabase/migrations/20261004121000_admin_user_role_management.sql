-- Profile privilege changes are allowed only inside the checked RPC below.
create or replace function public.protect_profile_privileged_fields()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  if (new.role <> old.role or new.account_status <> old.account_status)
     and auth.role() <> 'service_role'
     and not (
       current_user = 'postgres'
       and current_setting('ranco.admin_profile_write', true) = 'on'
     ) then
    raise exception 'profile role and account status require a privileged server-side operation'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.admin_change_user_role(
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_old_role public.app_role;
  v_status public.account_status;
  v_anonymous boolean;
  v_new_role public.app_role;
begin
  if v_actor is null or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_user_id is null or p_role not in ('customer', 'provider', 'admin') then
    raise exception 'INVALID_ROLE_CHANGE' using errcode = '22023';
  end if;
  v_new_role := p_role::public.app_role;

  -- Serialize demotions so two administrators cannot both remove the last one.
  perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
  select p.role, p.account_status, coalesce(u.is_anonymous, false)
  into v_old_role, v_status, v_anonymous
  from public.profiles p join auth.users u on u.id = p.id
  where p.id = p_user_id
  for update of p;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = '22023';
  end if;
  if v_old_role = 'super_admin' or v_anonymous
     or v_status in ('blocked', 'deleted') then
    raise exception 'ROLE_CHANGE_NOT_ALLOWED' using errcode = '42501';
  end if;
  if v_old_role = v_new_role then return; end if;
  if v_old_role = 'admin' and v_new_role <> 'admin'
     and (select count(*) from public.profiles p
          where p.role in ('admin', 'super_admin')
            and p.account_status = 'active') <= 1 then
    raise exception 'LAST_ADMIN' using errcode = '23514';
  end if;
  if v_new_role = 'admin' and v_status <> 'active' then
    raise exception 'ADMIN_MUST_BE_ACTIVE' using errcode = '23514';
  end if;
  perform set_config('ranco.admin_profile_write', 'on', true);
  update public.profiles set role = v_new_role where id = p_user_id;
  perform set_config('ranco.admin_profile_write', 'off', true);
  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_actor, 'user_role_changed', 'profile', p_user_id,
    jsonb_build_object('role', v_old_role),
    jsonb_build_object('role', v_new_role)
  );
end;
$$;

revoke all on function public.admin_change_user_role(uuid, text)
from public, anon, authenticated, service_role;
grant execute on function public.admin_change_user_role(uuid, text)
to authenticated;
