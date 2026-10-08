begin;

insert into auth.users (id, email, is_anonymous, raw_user_meta_data)
values
  ('00000000-0000-4000-8000-000000032101', 'phase321-admin@example.test', false, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000032102', 'phase321-provider@example.test', false,
    '{"full_name":"Provider 321","provider_registration":true}'::jsonb),
  ('00000000-0000-4000-8000-000000032103', 'phase321-user@example.test', false, '{}'::jsonb),
  ('00000000-0000-4000-8000-000000032104', 'phase321-upgrade@example.test', false, '{}'::jsonb);

do $$ begin
  if (select role from public.profiles where id = '00000000-0000-4000-8000-000000032102') <> 'provider' then
    raise exception 'provider signup role missing';
  end if;
end $$;

update public.profiles set role = 'super_admin'
where id = '00000000-0000-4000-8000-000000032101';
insert into public.super_admin_sessions(user_id,purpose,expires_at) values('00000000-0000-4000-8000-000000032101','Phase 3.21 contract admin session',now()+interval '50 minutes');

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032104', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032104","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  begin
    perform public.create_business_draft('service', 'Too Early');
    raise exception 'customer created provider draft';
  exception when insufficient_privilege then null;
  end;
  perform public.register_provider_identity();
  if not public.current_user_is_provider() then
    raise exception 'provider identity upgrade failed';
  end if;
  perform public.create_business_draft('service', 'Upgraded Business');
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032102', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032102","role":"authenticated","is_anonymous":false}', true);

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032102', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032102","role":"authenticated","is_anonymous":false}', true);

do $$
declare first_draft uuid; second_draft uuid;
begin
  first_draft := public.create_business_draft('service', 'Test Service 321');
  second_draft := public.create_business_draft('service', 'Test Service 321');
  if first_draft <> second_draft then raise exception 'draft was not reused'; end if;
  if (select count(*) from public.businesses where owner_id = auth.uid()) <> 1 then
    raise exception 'duplicate business draft';
  end if;
  if exists(select 1 from public.business_review_requirements(first_draft)
    where requirement_key = 'lodging_details') then
    raise exception 'lodging requirement shown for service';
  end if;
  begin
    perform public.admin_change_user_role(auth.uid(), 'admin');
    raise exception 'provider self escalation accepted';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032101', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032101","role":"authenticated","is_anonymous":false}', true);

do $$
declare category_row public.categories;
begin
  if not public.admin_user_mutations_ready() then
    raise exception 'admin mutation capability unavailable';
  end if;
  begin
    perform public.admin_change_user_role(auth.uid(), 'customer');
    raise exception 'last admin demoted';
  exception when insufficient_privilege then
    if sqlerrm not like '%ROLE_CHANGE_NOT_ALLOWED%' then raise; end if;
  end;

  begin
    perform public.admin_change_user_role('00000000-0000-4000-8000-000000032104', 'admin');
    raise exception 'business owner promoted to admin';
  exception when check_violation then
    if sqlerrm not like '%PROVIDER_HAS_BUSINESS%' then raise; end if;
  end;

  perform public.admin_change_user_role('00000000-0000-4000-8000-000000032103', 'admin');
  if not exists(select 1 from public.audit_logs
    where action = 'user_role_changed'
      and entity_id = '00000000-0000-4000-8000-000000032103') then
    raise exception 'role audit missing';
  end if;

  category_row := public.admin_upsert_category(null, 'Phase 321', 'phase-321', true);
  if not exists(select 1 from public.audit_logs
    where action = 'category_created' and entity_id = category_row.id) then
    raise exception 'category audit missing';
  end if;

  perform public.admin_set_account_suspension(
    '00000000-0000-4000-8000-000000032102', true);
  if not exists(select 1 from public.audit_logs
    where action = 'user_suspended'
      and entity_id = '00000000-0000-4000-8000-000000032102') then
    raise exception 'suspension audit missing';
  end if;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032102', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032102","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  if public.account_session_allowed() then
    raise exception 'suspended session accepted';
  end if;
  if exists(select 1 from public.businesses where owner_id = auth.uid()) then
    raise exception 'suspended user read private business';
  end if;
  begin
    perform public.create_business_draft('service', 'Blocked');
    raise exception 'suspended user created business';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000032101', true);
select set_config('request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000032101","role":"authenticated","is_anonymous":false}', true);
do $$ begin
  perform public.admin_set_account_suspension(
    '00000000-0000-4000-8000-000000032102', false);
  if not exists(select 1 from public.audit_logs
    where action = 'user_reactivated'
      and entity_id = '00000000-0000-4000-8000-000000032102') then
    raise exception 'reactivation audit missing';
  end if;
end $$;

rollback;
select 'phase 3.21 security flow checks passed' as result;


