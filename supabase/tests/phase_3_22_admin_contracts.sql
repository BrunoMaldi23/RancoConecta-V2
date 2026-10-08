begin;

insert into auth.users (id, email, is_anonymous, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000032201', 'phase322-admin@example.test', false, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000032202', 'phase322-user@example.test', false, '{}'::jsonb);
update public.profiles set role = 'super_admin'
where id = '00000000-0000-4000-8000-000000032201';
insert into public.super_admin_sessions(user_id,purpose,expires_at) values('00000000-0000-4000-8000-000000032201','Phase 3.22 contract admin session',now()+interval '50 minutes');

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032201', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032201","role":"authenticated","is_anonymous":false}', true);

do $$
declare v_page jsonb;
begin
  begin
    update public.system_settings set value = 'true'::jsonb
    where key = 'whatsapp_notifications_enabled';
    raise exception 'direct settings update was permitted';
  exception when insufficient_privilege then null;
  end;

  begin
    perform public.admin_update_whatsapp_settings('56abc', true, true, true, true);
    raise exception 'invalid number was accepted';
  exception when invalid_parameter_value then null;
  end;

  perform public.admin_update_whatsapp_settings('56912345678', true, true, false, true);
  if not exists (select 1 from public.audit_logs
      where action = 'admin_settings_updated' and actor_id = auth.uid()) then
    raise exception 'settings audit missing';
  end if;

  v_page := public.admin_search_users(1, 10, 'phase322-', null, 'active');
  if (v_page ->> 'total_count')::integer <> 2 then
    raise exception 'active user filter returned wrong count';
  end if;
  begin
    perform public.admin_search_users(0, 10, null, null, null);
    raise exception 'invalid page was accepted';
  exception when invalid_parameter_value then null;
  end;
end $$;

rollback;
