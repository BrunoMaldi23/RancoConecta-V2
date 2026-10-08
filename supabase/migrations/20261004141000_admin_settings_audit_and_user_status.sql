-- Keep administrative settings changes behind one validated, audited RPC.
drop policy if exists "admins update system settings" on public.system_settings;
revoke update on public.system_settings from authenticated;

create or replace function public.admin_update_whatsapp_settings(
  p_number text,
  p_enabled boolean,
  p_new_business boolean,
  p_changes boolean,
  p_reports boolean
)
returns void
language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_number text := btrim(coalesce(p_number, ''));
  v_old jsonb;
  v_new jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_enabled is null or p_new_business is null or p_changes is null
     or p_reports is null then
    raise exception 'INVALID_SETTINGS' using errcode = '22023';
  end if;
  if v_number <> '' and v_number !~ '^\+?[1-9][0-9]{7,14}$' then
    raise exception 'INVALID_WHATSAPP_NUMBER' using errcode = '22023';
  end if;
  if p_enabled and v_number = '' then
    raise exception 'INVALID_WHATSAPP_NUMBER' using errcode = '22023';
  end if;
  v_number := ltrim(v_number, '+');

  select jsonb_object_agg(key, value) into v_old
  from public.system_settings
  where key in ('admin_whatsapp_number', 'whatsapp_notifications_enabled',
    'whatsapp_notify_new_business', 'whatsapp_notify_business_changes',
    'whatsapp_notify_user_reports');

  update public.system_settings
  set value = case key
    when 'admin_whatsapp_number' then to_jsonb(v_number)
    when 'whatsapp_notifications_enabled' then to_jsonb(p_enabled)
    when 'whatsapp_notify_new_business' then to_jsonb(p_new_business)
    when 'whatsapp_notify_business_changes' then to_jsonb(p_changes)
    when 'whatsapp_notify_user_reports' then to_jsonb(p_reports)
  end,
  updated_at = now(), updated_by = auth.uid()
  where key in ('admin_whatsapp_number', 'whatsapp_notifications_enabled',
    'whatsapp_notify_new_business', 'whatsapp_notify_business_changes',
    'whatsapp_notify_user_reports');

  select jsonb_object_agg(key, value) into v_new
  from public.system_settings
  where key in ('admin_whatsapp_number', 'whatsapp_notifications_enabled',
    'whatsapp_notify_new_business', 'whatsapp_notify_business_changes',
    'whatsapp_notify_user_reports');
  if v_old is distinct from v_new then
    insert into public.audit_logs (actor_id, action, entity_type, old_data, new_data)
    values (auth.uid(), 'admin_settings_updated', 'system_settings',
      v_old, v_new);
  end if;
end;
$$;

-- Preserve the existing 4-argument RPC for deployed clients; the new client
-- uses this 5-argument signature for server-side account-status filtering.
create or replace function public.admin_search_users(
  p_page integer,
  p_page_size integer,
  p_search text,
  p_role text,
  p_status text
)
returns jsonb
language plpgsql stable security definer
set search_path = pg_catalog
as $$
declare
  v_total bigint;
  v_rows jsonb;
  v_search text;
begin
  if auth.uid() is null or coalesce(auth.jwt() ->> 'is_anonymous', 'false') = 'true'
     or not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_page is null or p_page not between 1 and 10000
     or p_page_size is null or p_page_size not in (10, 20, 50)
     or (p_role is not null and p_role not in ('CUSTOMER', 'PROVIDER', 'ADMIN', 'VISITOR'))
     or (p_status is not null and p_status not in ('active', 'pending', 'suspended', 'blocked', 'deleted'))
     or (p_search is not null and char_length(p_search) > 100) then
    raise exception 'INVALID_USER_PAGE' using errcode = '22023';
  end if;
  v_search := nullif(btrim(p_search), '');

  select count(*) into v_total
  from public.profiles p join auth.users u on u.id = p.id
  where (p_status is null or p.account_status::text = p_status)
    and (p_role is null or
      (p_role = 'ADMIN' and p.role::text in ('admin', 'super_admin')) or
      (p_role = 'VISITOR' and u.is_anonymous) or
      (p_role = 'CUSTOMER' and p.role::text = 'customer' and not u.is_anonymous) or
      (p_role = 'PROVIDER' and p.role::text = 'provider'))
    and (v_search is null or p.full_name ilike '%' || v_search || '%'
      or u.email ilike '%' || v_search || '%');

  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc, r.id desc), '[]'::jsonb)
    into v_rows
  from (
    select p.id, p.full_name, u.email::text, p.role::text as role,
      p.account_status::text as account_status, p.created_at,
      coalesce(u.is_anonymous, false) as is_anonymous
    from public.profiles p join auth.users u on u.id = p.id
    where (p_status is null or p.account_status::text = p_status)
      and (p_role is null or
        (p_role = 'ADMIN' and p.role::text in ('admin', 'super_admin')) or
        (p_role = 'VISITOR' and u.is_anonymous) or
        (p_role = 'CUSTOMER' and p.role::text = 'customer' and not u.is_anonymous) or
        (p_role = 'PROVIDER' and p.role::text = 'provider'))
      and (v_search is null or p.full_name ilike '%' || v_search || '%'
        or u.email ilike '%' || v_search || '%')
    order by p.created_at desc, p.id desc
    limit p_page_size offset (p_page - 1)::bigint * p_page_size
  ) r;
  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;

revoke all on function public.admin_search_users(integer, integer, text, text, text)
from public, anon, authenticated, service_role;
grant execute on function public.admin_search_users(integer, integer, text, text, text)
to authenticated;
