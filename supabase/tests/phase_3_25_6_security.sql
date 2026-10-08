-- Carried-forward base security regression under the final ADMIN/PROVIDER/ANON
-- model. Historical tests that created customer/super_admin rows are retired.
begin;
do $$
declare t record; v_count bigint;
begin
  for t in select c.oid,n.nspname,c.relname from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') loop
    if has_table_privilege('anon',t.oid,'TRUNCATE') or
       has_table_privilege('authenticated',t.oid,'TRUNCATE') then
      raise exception 'application role retains TRUNCATE on %.%',t.nspname,t.relname;
    end if;
    if has_table_privilege('anon',t.oid,'REFERENCES') or
       has_table_privilege('authenticated',t.oid,'REFERENCES') or
       has_table_privilege('anon',t.oid,'TRIGGER') or
       has_table_privilege('authenticated',t.oid,'TRIGGER') then
      raise exception 'application role retains REFERENCES/TRIGGER on %.%',t.nspname,t.relname;
    end if;
  end loop;
  select count(*) into v_count from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prosecdef
      and has_function_privilege('anon',p.oid,'EXECUTE') and p.proname like 'admin_%';
  if v_count<>0 then raise exception 'anon can execute admin SECURITY DEFINER RPC'; end if;
  if exists(select 1 from public.profiles where role::text in ('customer','super_admin')) then
    raise exception 'retired product roles remain active in profiles';
  end if;
  if not exists(select 1 from pg_constraint where conrelid='public.businesses'::regclass
       and conname='businesses_owner_id_fkey' and confdeltype='r'
       and confrelid='public.profiles'::regclass) then
    raise exception 'business ownership FK must RESTRICT to profiles';
  end if;
  if has_table_privilege('anon','public.contact_messages','SELECT')
    or has_table_privilege('anon','public.contact_messages','INSERT')
    or has_table_privilege('authenticated','public.contact_messages','INSERT') then
    raise exception 'contact_messages direct API access exists';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.contact_messages'::regclass) then
    raise exception 'contact_messages RLS disabled';
  end if;
end;
$$;
rollback;
select 'phase 3.25.6 carried-forward security contracts passed' as result;
