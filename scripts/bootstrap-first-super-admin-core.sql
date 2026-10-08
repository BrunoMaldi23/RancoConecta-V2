-- Internal psql include shared by the one-shot operator script and local test.
do $bootstrap$
declare
  v_user_id uuid := nullif(current_setting('ranco.bootstrap_user_id', true), '')::uuid;
  v_role text;
  v_status text;
  v_is_anonymous boolean;
begin
  if current_user not in ('postgres', 'supabase_admin') then
    raise exception 'BOOTSTRAP_REQUIRES_DATABASE_OWNER' using errcode = '42501';
  end if;
  if auth.uid() is not null and auth.uid() = v_user_id then
    raise exception 'BOOTSTRAP_SELF_PROMOTION_FORBIDDEN' using errcode = '42501';
  end if;
  if (select count(*) from public.profiles where role::text = 'super_admin') <> 0 then
    raise exception 'BOOTSTRAP_ALREADY_COMPLETED' using errcode = '55000';
  end if;

  select p.role::text, p.account_status::text, coalesce(u.is_anonymous, true)
    into v_role, v_status, v_is_anonymous
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id = v_user_id
  for update of p;
  if not found then
    raise exception 'BOOTSTRAP_TARGET_NOT_FOUND' using errcode = '22023';
  end if;
  if v_role <> 'admin' or v_status <> 'active' or v_is_anonymous then
    raise exception 'BOOTSTRAP_TARGET_MUST_BE_ACTIVE_TENANT_ADMIN'
      using errcode = '22023';
  end if;

  perform set_config('ranco.admin_profile_write', 'on', true);
  update public.profiles set role = 'super_admin'::public.app_role where id = v_user_id;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_data, new_data)
  values (null, 'first_super_admin_bootstrapped', 'profile', v_user_id,
    jsonb_build_object('role', 'admin'),
    jsonb_build_object('role', 'super_admin', 'method', 'one_shot_database_owner'));

  if (select count(*) from public.profiles where role::text = 'super_admin') <> 1
     or not exists (select 1 from public.profiles where id = v_user_id
       and role::text = 'super_admin' and account_status::text = 'active') then
    raise exception 'BOOTSTRAP_POSTCONDITION_FAILED' using errcode = '23514';
  end if;
end;
$bootstrap$;
