-- Integration contract over synthetic ids seeded only in the isolated model.
begin;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032905',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032905","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ declare v_rejected boolean := false; begin
  if public.current_user_is_admin() then
    raise exception 'tenant admin crossed the global session gate';
  end if;
  if public.is_business_admin('00000000-0000-4000-8000-000000032931') then
    raise exception 'tenant admin received owner scope without membership';
  end if;
  begin
    perform public.admin_analytics_summary();
  exception when others then v_rejected := true;
  end;
  if not v_rejected then raise exception 'tenant admin executed global analytics RPC'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032901',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032901","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'customer has global admin'; end if;
  if not public.is_business_admin('00000000-0000-4000-8000-000000032931') then
    raise exception 'business owner lost own business scope';
  end if;
  if public.is_business_admin('00000000-0000-4000-8000-000000032932') then
    raise exception 'business owner escaped to another tenant';
  end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032904',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032904","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
  if public.current_user_is_admin() then raise exception 'provider acquired global admin'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000032906',true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000032906","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$
begin
  if public.current_user_is_admin() then
    raise exception 'SuperAdmin passed global gate without explicit session';
  end if;
  perform public.start_super_admin_session('Phase 3.29 authorization contract',30);
  if not public.current_user_is_admin() then
    raise exception 'explicit SuperAdmin session failed to open global gate';
  end if;
  perform public.end_super_admin_session();
  if public.current_user_is_admin() then
    raise exception 'ended SuperAdmin session still opens global gate';
  end if;
end;
$$;
reset role;

rollback;
select 'phase 3.29 authorization matrix contracts passed' as result;
