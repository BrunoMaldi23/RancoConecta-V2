create or replace function public.admin_set_account_suspension(
  p_user_id uuid,
  p_suspended boolean
)
returns void
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.app_role;
  v_old_status public.account_status;
  v_new_status public.account_status;
begin
  if v_actor is null or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_user_id is null or p_suspended is null or p_user_id = v_actor then
    raise exception 'INVALID_SUSPENSION' using errcode = '22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
  select p.role, p.account_status into v_role, v_old_status
  from public.profiles p where p.id = p_user_id for update;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = '22023';
  end if;
  if v_role = 'super_admin' or v_old_status in ('blocked', 'deleted') then
    raise exception 'SUSPENSION_NOT_ALLOWED' using errcode = '42501';
  end if;
  v_new_status := case when p_suspended
    then 'suspended'::public.account_status
    else 'active'::public.account_status end;
  if v_old_status = v_new_status then return; end if;
  if not p_suspended and v_old_status <> 'suspended' then
    raise exception 'INVALID_REACTIVATION' using errcode = '23514';
  end if;
  if p_suspended and v_role = 'admin'
     and (select count(*) from public.profiles p
          where p.role in ('admin', 'super_admin')
            and p.account_status = 'active') <= 1 then
    raise exception 'LAST_ADMIN' using errcode = '23514';
  end if;
  perform set_config('ranco.admin_profile_write', 'on', true);
  update public.profiles set account_status = v_new_status where id = p_user_id;
  perform set_config('ranco.admin_profile_write', 'off', true);
  insert into public.audit_logs (
    actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_actor, case when p_suspended then 'user_suspended' else 'user_reactivated' end,
    'profile', p_user_id,
    jsonb_build_object('account_status', v_old_status),
    jsonb_build_object('account_status', v_new_status)
  );
end;
$$;

revoke all on function public.admin_set_account_suspension(uuid, boolean)
from public, anon, authenticated, service_role;
grant execute on function public.admin_set_account_suspension(uuid, boolean)
to authenticated;
