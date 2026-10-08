-- Preserve related records and audit history when an administrator removes access.
create or replace function public.admin_mark_user_deleted(p_user_id uuid)
returns jsonb language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_actor uuid := auth.uid();
  v_role public.app_role;
  v_status public.account_status;
  v_related jsonb := '[]'::jsonb;
  v_has_rows boolean;
  v_fk record;
begin
  if v_actor is null or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_user_id is null or p_user_id = v_actor then
    raise exception 'SELF_DELETE_NOT_ALLOWED' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ranco.admin.role.count', 0));
  select role, account_status into v_role, v_status
  from public.profiles where id = p_user_id for update;
  if not found then
    raise exception 'USER_NOT_FOUND' using errcode = '22023';
  end if;
  if v_role = 'super_admin' then
    raise exception 'PROTECTED_ADMIN' using errcode = '42501';
  end if;
  if v_role = 'admin' and v_status = 'active' and
     (select count(*) from public.profiles
      where role in ('admin', 'super_admin') and account_status = 'active') <= 1 then
    raise exception 'LAST_ADMIN' using errcode = '23514';
  end if;

  -- Inspect all public foreign keys to the profile or Auth user before
  -- changing status. References stay intact; no physical cascade occurs.
  for v_fk in
    select n.nspname, c.relname, a.attname
    from pg_constraint fk
    join pg_class c on c.oid = fk.conrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_attribute a on a.attrelid = c.oid and a.attnum = fk.conkey[1]
    where fk.contype = 'f' and n.nspname = 'public'
      and fk.confrelid in ('public.profiles'::regclass, 'auth.users'::regclass)
      and array_length(fk.conkey, 1) = 1
  loop
    execute format('select exists(select 1 from %I.%I where %I = $1)',
      v_fk.nspname, v_fk.relname, v_fk.attname)
      into v_has_rows using p_user_id;
    if v_has_rows then
      v_related := v_related || to_jsonb(v_fk.relname);
    end if;
  end loop;

  if v_status <> 'deleted' then
    perform set_config('ranco.admin_profile_write', 'on', true);
    update public.profiles
    set account_status = 'deleted', full_name = null, phone = null,
      avatar_url = null
    where id = p_user_id;
    perform set_config('ranco.admin_profile_write', 'off', true);
    insert into public.audit_logs
      (actor_id, action, entity_type, entity_id, old_data, new_data)
    values (v_actor, 'user_deleted', 'profile', p_user_id,
      jsonb_build_object('account_status', v_status),
      jsonb_build_object('account_status', 'deleted',
        'related_tables', v_related));
  end if;
  return jsonb_build_object('related_tables', v_related);
end;
$$;

revoke all on function public.admin_mark_user_deleted(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.admin_mark_user_deleted(uuid) to authenticated;
