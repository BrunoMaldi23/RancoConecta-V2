-- Transactional local integration test. Run with psql -v ON_ERROR_STOP=1.
begin;

insert into auth.users (id, email, is_anonymous, raw_user_meta_data) values
  ('00000000-0000-4000-8000-000000032501', 'qa3252-admin-a@example.test', false, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000032502', 'qa3252-admin-b@example.test', false, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000032503', 'qa3252-user@example.test', false, '{}'::jsonb);

select set_config('ranco.admin_profile_write', 'on', true);
update public.profiles set role = 'super_admin', account_status = 'active'
where id in ('00000000-0000-4000-8000-000000032501',
             '00000000-0000-4000-8000-000000032502');
update public.profiles set account_status = 'active'
where id = '00000000-0000-4000-8000-000000032503';
select set_config('ranco.admin_profile_write', 'off', true);
insert into public.super_admin_sessions(user_id,purpose,expires_at) values
 ('00000000-0000-4000-8000-000000032501','Phase 3.25.2 contract admin session',now()+interval '50 minutes'),
 ('00000000-0000-4000-8000-000000032502','Phase 3.25.2 second admin session',now()+interval '50 minutes');

do $$
declare
  v_table oid := 'public.contact_messages'::regclass;
begin
  if exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and left(p.proname, 6) = 'admin_'
      and has_function_privilege('anon', p.oid, 'execute')
  ) then
    raise exception 'anonymous role can execute a SECURITY DEFINER admin RPC';
  end if;
  if not (select relrowsecurity from pg_class where oid = v_table) then
    raise exception 'contact RLS disabled';
  end if;
  if has_table_privilege('anon', v_table, 'SELECT') or
     has_table_privilege('anon', v_table, 'INSERT') or
     has_table_privilege('authenticated', v_table, 'INSERT') or
     has_table_privilege('authenticated', v_table, 'UPDATE') or
     has_table_privilege('authenticated', v_table, 'DELETE') then
    raise exception 'direct contact privilege is too broad';
  end if;
  if (select count(*) from pg_policy where polrelid = v_table) <> 1 then
    raise exception 'unexpected contact policies';
  end if;
  if not exists (select 1 from pg_trigger where tgrelid = v_table
      and tgname = 'notify_admins_on_contact_message' and not tgisinternal) then
    raise exception 'contact notification trigger missing';
  end if;
  if not exists (select 1 from pg_indexes where tablename = 'contact_messages'
      and indexname = 'contact_messages_status_created_idx') then
    raise exception 'contact status index missing';
  end if;
end $$;

insert into public.contact_messages (id, name, email, subject, message, user_id)
values ('00000000-0000-4000-8000-000000032504', 'QA User', 'qa@example.test',
  'Consulta general', 'Consulta local válida.',
  '00000000-0000-4000-8000-000000032503');

do $$ begin
  if (select status from public.contact_messages
      where id = '00000000-0000-4000-8000-000000032504') <> 'new' then
    raise exception 'contact default status incorrect';
  end if;
  if (select count(*) from public.notifications
      where type = 'contact_message'
      and entity_id = '00000000-0000-4000-8000-000000032504') <> 2 then
    raise exception 'admin contact recipients incorrect';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032503', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032503","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if exists(select 1 from public.contact_messages) then
    raise exception 'normal user read admin contacts';
  end if;
  begin
    perform public.admin_set_contact_message_status(
      '00000000-0000-4000-8000-000000032504', 'resolved');
    raise exception 'normal user changed contact status';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.admin_update_contact_channels('qa@example.test', '56912345678');
    raise exception 'normal user changed contact settings';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.admin_change_user_role(
      '00000000-0000-4000-8000-000000032503', 'admin');
    raise exception 'normal user changed role';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032501', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032501","role":"authenticated","is_anonymous":false}', true);

select public.admin_set_contact_message_status(
  '00000000-0000-4000-8000-000000032504', 'in_review');
select public.admin_update_contact_channels('QA@example.test', '+56912345678');
select public.admin_update_notification_settings(false, true, false);
select public.admin_change_user_role('00000000-0000-4000-8000-000000032503', 'provider');
select public.admin_set_account_suspension('00000000-0000-4000-8000-000000032503', true);
select public.admin_set_account_suspension('00000000-0000-4000-8000-000000032503', false);

reset role;
insert into public.businesses (id, owner_id, business_type, name, slug)
values ('00000000-0000-4000-8000-000000032505',
  '00000000-0000-4000-8000-000000032503', 'service', 'QA Business', 'qa-business-3252');
insert into public.notifications (user_id, type, title, body)
values ('00000000-0000-4000-8000-000000032503', 'system_notice', 'QA', 'QA');
set local role authenticated;

do $$ begin
  begin
    perform public.admin_set_account_suspension(
      '00000000-0000-4000-8000-000000032501', true);
    raise exception 'self suspension accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.admin_mark_user_deleted('00000000-0000-4000-8000-000000032501');
    raise exception 'self deletion accepted';
  exception when insufficient_privilege then null;
  end;
end $$;

select public.admin_mark_user_deleted('00000000-0000-4000-8000-000000032503');

do $$ begin
  if (public.admin_search_users(1, 10, 'qa3252-user', null, 'active')
      ->> 'total_count')::integer <> 0 then
    raise exception 'deleted user still appears in active admin search';
  end if;
end $$;

reset role;
do $$ begin
  if (select account_status from public.profiles
      where id = '00000000-0000-4000-8000-000000032503') <> 'deleted' or
     (select full_name from public.profiles
      where id = '00000000-0000-4000-8000-000000032503') is not null then
    raise exception 'logical deletion did not anonymize profile';
  end if;
  if not exists(select 1 from public.businesses
      where id = '00000000-0000-4000-8000-000000032505'
      and owner_id = '00000000-0000-4000-8000-000000032503') or
     not exists(select 1 from public.notifications
      where user_id = '00000000-0000-4000-8000-000000032503') then
    raise exception 'logical deletion destroyed related history';
  end if;
  if (select count(*) from public.audit_logs
      where actor_id = '00000000-0000-4000-8000-000000032501'
      and action in ('contact_message_status_changed', 'admin_settings_updated',
        'user_role_changed', 'user_suspended', 'user_reactivated', 'user_deleted')) < 7 then
    raise exception 'administrative audit entries missing';
  end if;
end $$;

rollback;
