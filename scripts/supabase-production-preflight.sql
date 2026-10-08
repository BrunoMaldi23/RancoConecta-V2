-- Aggregate-only production baseline. Contains no names, emails, or row payloads.
select metric, value
from (
  select 'profiles.total' metric, count(*)::bigint value from public.profiles
  union all select 'profiles.role.' || role::text, count(*)::bigint from public.profiles group by role::text
  union all select 'profiles.active_admin_or_super_admin', count(*)::bigint from public.profiles
    where role::text in ('admin','super_admin') and account_status::text='active'
  union all select 'businesses.total', count(*)::bigint from public.businesses
  union all select 'businesses.owner_without_profile', count(*)::bigint from public.businesses b
    left join public.profiles p on p.id=b.owner_id where p.id is null
  union all select 'businesses.owner_without_auth', count(*)::bigint from public.businesses b
    left join auth.users u on u.id=b.owner_id where u.id is null
  union all select 'service_requests.total', count(*)::bigint from public.service_requests
  union all select 'lodging_bookings.total', count(*)::bigint from public.lodging_bookings
  union all select 'gastronomy_table_reservations.total', count(*)::bigint from public.gastronomy_table_reservations
  union all select 'notifications.total', count(*)::bigint from public.notifications
  union all select 'audit_logs.total', count(*)::bigint from public.audit_logs
) baseline
order by metric;
