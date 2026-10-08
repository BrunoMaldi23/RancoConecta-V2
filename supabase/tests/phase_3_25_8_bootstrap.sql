-- Local-only contract for the exact one-shot bootstrap core. All changes rollback.
-- Run with psql -v ON_ERROR_STOP=1 -f this file after a clean db reset.
begin;

insert into auth.users (id, email, is_anonymous) values
 ('00000000-0000-4000-8000-000000032801','phase328-admin-one@example.test',false),
 ('00000000-0000-4000-8000-000000032802','phase328-admin-two@example.test',false),
 ('00000000-0000-4000-8000-000000032803','phase328-provider@example.test',false),
 ('00000000-0000-4000-8000-000000032804','phase328-customer@example.test',false);

select set_config('ranco.admin_profile_write','on',true);
update public.profiles set account_status='active' where id in (
 '00000000-0000-4000-8000-000000032801','00000000-0000-4000-8000-000000032802',
 '00000000-0000-4000-8000-000000032803','00000000-0000-4000-8000-000000032804');
update public.profiles set role='admin' where id in (
 '00000000-0000-4000-8000-000000032801','00000000-0000-4000-8000-000000032802');
update public.profiles set role='provider' where id='00000000-0000-4000-8000-000000032803';
select set_config('ranco.admin_profile_write','off',true);

do $$ begin
  if exists(select 1 from public.profiles where role='super_admin') then
    raise exception 'fixture must start with zero super_admin';
  end if;
end $$;
select set_config('ranco.bootstrap_user_id','00000000-0000-4000-8000-000000032801',true);
select pg_advisory_xact_lock(hashtextextended('ranco:first-super-admin-bootstrap',0));
\ir ../../scripts/bootstrap-first-super-admin-core.sql

do $$ begin
  if (select count(*) from public.profiles where role='super_admin') <> 1 then
    raise exception 'bootstrap must produce exactly one super_admin';
  end if;
  if (select role::text from public.profiles where id='00000000-0000-4000-8000-000000032802') <> 'admin' then
    raise exception 'other tenant admin changed';
  end if;
  if (select role::text from public.profiles where id='00000000-0000-4000-8000-000000032803') <> 'provider'
     or (select role::text from public.profiles where id='00000000-0000-4000-8000-000000032804') <> 'customer' then
    raise exception 'provider/customer changed';
  end if;
  if not exists(select 1 from public.audit_logs where action='first_super_admin_bootstrapped'
      and entity_id='00000000-0000-4000-8000-000000032801' and actor_id is null) then
    raise exception 'bootstrap audit missing';
  end if;
  begin
    if (select count(*) from public.profiles where role='super_admin') <> 0 then
      raise exception 'BOOTSTRAP_ALREADY_COMPLETED' using errcode = '55000';
    end if;
    raise exception 'second bootstrap was not rejected';
  exception when sqlstate '55000' then null;
  end;
end $$;

-- No API user can execute the privileged bootstrap path or edit role directly.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032802',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032802","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
  begin
    update public.profiles set role='super_admin'
    where id='00000000-0000-4000-8000-000000032802';
    raise exception 'tenant admin self promotion succeeded';
  exception when insufficient_privilege then null;
  end;
  if public.current_user_is_admin() then raise exception 'tenant admin acquired global session'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032803',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032803","role":"authenticated","is_anonymous":false}',true);
do $$ begin
  begin
    update public.profiles set role='super_admin'
    where id='00000000-0000-4000-8000-000000032803';
    raise exception 'provider self promotion succeeded';
  exception when insufficient_privilege then null;
  end;
  if public.current_user_is_admin() then raise exception 'provider acquired global session'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032804',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032804","role":"authenticated","is_anonymous":false}',true);
do $$ begin
  begin
    update public.profiles set role='super_admin'
    where id='00000000-0000-4000-8000-000000032804';
    raise exception 'customer self promotion succeeded';
  exception when insufficient_privilege then null;
  end;
  if public.current_user_is_admin() then raise exception 'customer acquired global session'; end if;
end $$;
reset role;

-- Global identity is gated by an explicit audited session; last platform admin
-- cannot be demoted or soft-deleted through administrative RPCs.
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032801',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032801","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'global access without session'; end if;
  perform public.start_super_admin_session('Phase 3.25.8 local bootstrap test',30);
  if not public.current_user_is_admin() then raise exception 'explicit session did not grant global gate'; end if;
  begin perform public.admin_change_user_role(auth.uid(),'admin');
    raise exception 'super_admin demotion unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
  begin perform public.admin_mark_user_deleted(auth.uid());
    raise exception 'super_admin self deletion unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

rollback;
select 'phase 3.25.8 bootstrap contracts passed' as result;
