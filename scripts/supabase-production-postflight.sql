-- Structural/security assertions plus aggregate counts. Run only after bootstrap.
do $$
declare t record;
begin
  if exists(select 1 from public.businesses b left join public.profiles p on p.id=b.owner_id where p.id is null) then
    raise exception 'POSTCHECK_ORPHAN_BUSINESS_OWNER';
  end if;
  if not exists(select 1 from pg_constraint c
      where c.conrelid='public.businesses'::regclass and c.conname='businesses_owner_id_fkey'
        and c.contype='f' and c.confrelid='public.profiles'::regclass
        and c.confdeltype='r' and c.convalidated) then
    raise exception 'POSTCHECK_OWNER_FK_NOT_PROFILES_RESTRICT';
  end if;
  if (select count(*) from public.profiles where role::text='super_admin' and account_status::text='active') <> 1 then
    raise exception 'POSTCHECK_EXPECTED_EXACTLY_ONE_ACTIVE_SUPER_ADMIN';
  end if;
  if exists(select 1 from public.provider_role_migration_candidates c
      join public.profiles p on p.id=c.profile_id
      where c.original_role='customer'
        and c.resolution in ('AMBIGUO','DEBE_SEGUIR_CUSTOMER')
        and p.role::text <> 'customer') then
    raise exception 'POSTCHECK_AMBIGUOUS_CUSTOMER_ROLE_CHANGED';
  end if;
  if to_regclass('public.contact_messages') is null then
    raise exception 'POSTCHECK_CONTACT_TABLE_MISSING';
  end if;
  if not (select c.relrowsecurity from pg_class c where c.oid='public.contact_messages'::regclass) then
    raise exception 'POSTCHECK_CONTACT_RLS_DISABLED';
  end if;
  if has_table_privilege('anon','public.contact_messages','SELECT') or
     has_table_privilege('anon','public.contact_messages','INSERT') or
     has_table_privilege('anon','public.contact_messages','UPDATE') or
     has_table_privilege('anon','public.contact_messages','DELETE') or
     has_table_privilege('authenticated','public.contact_messages','INSERT') or
     has_table_privilege('authenticated','public.contact_messages','UPDATE') or
     has_table_privilege('authenticated','public.contact_messages','DELETE') then
    raise exception 'POSTCHECK_CONTACT_GRANTS_TOO_BROAD';
  end if;
  if not (select bool_and(c.relrowsecurity) from pg_class c
      where c.oid in ('public.profiles'::regclass,'public.businesses'::regclass,
        'public.notifications'::regclass,'public.system_settings'::regclass,'public.audit_logs'::regclass)) then
    raise exception 'POSTCHECK_RLS_DISABLED_ON_CRITICAL_TABLE';
  end if;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
      where n.nspname='public' and p.prosecdef and p.proname like 'admin_%'
        and has_function_privilege('anon',p.oid,'EXECUTE')) then
    raise exception 'POSTCHECK_ANON_CAN_EXECUTE_ADMIN_RPC';
  end if;
  for t in select c.oid,n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind in ('r','p') loop
    if has_table_privilege('anon',t.oid,'TRUNCATE') or has_table_privilege('authenticated',t.oid,'TRUNCATE') then
      raise exception 'POSTCHECK_API_ROLE_HAS_TRUNCATE_ON_%.%',t.nspname,t.relname;
    end if;
  end loop;
  if (select count(*) from information_schema.columns where table_schema='public'
      and table_name='businesses' and column_name in ('is_featured','accepts_requests','rating_avg','review_count')) <> 4 then
    raise exception 'POSTCHECK_HOME_FIELDS_MISSING';
  end if;
  if to_regclass('public.idx_businesses_featured') is null then
    raise exception 'POSTCHECK_FEATURED_INDEX_MISSING';
  end if;
  if (select count(*) from public.system_settings where key in ('support_email','support_whatsapp',
      'notify_new_business','notify_business_changes','notify_contact_message')) <> 5 then
    raise exception 'POSTCHECK_SETTINGS_DEFAULTS_MISSING';
  end if;
end $$;

select metric, value
from (
  select 'profiles.total' metric, count(*)::bigint value from public.profiles
  union all select 'profiles.role.' || role::text, count(*)::bigint from public.profiles group by role::text
  union all select 'profiles.active_admin_or_super_admin', count(*)::bigint from public.profiles
    where role::text in ('admin','super_admin') and account_status::text='active'
  union all select 'businesses.total', count(*)::bigint from public.businesses
  union all select 'businesses.owner_without_profile', count(*)::bigint from public.businesses b
    left join public.profiles p on p.id=b.owner_id where p.id is null
  union all select 'service_requests.total', count(*)::bigint from public.service_requests
  union all select 'lodging_bookings.total', count(*)::bigint from public.lodging_bookings
  union all select 'gastronomy_table_reservations.total', count(*)::bigint from public.gastronomy_table_reservations
  union all select 'notifications.total', count(*)::bigint from public.notifications
  union all select 'audit_logs.total', count(*)::bigint from public.audit_logs
) after_state
order by metric;
