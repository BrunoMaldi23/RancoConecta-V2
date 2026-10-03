-- Admin-owned settings and first-party discovery analytics.
create table if not exists public.system_settings (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles(id) on delete set null
);

alter table public.system_settings enable row level security;

create policy "admins read system settings" on public.system_settings
for select to authenticated using (public.current_user_is_admin());

create policy "admins update system settings" on public.system_settings
for update to authenticated using (public.current_user_is_admin())
with check (public.current_user_is_admin());

grant select, update on public.system_settings to authenticated;

insert into public.system_settings (key, value) values
  ('admin_whatsapp_number', to_jsonb(''::text)),
  ('whatsapp_notifications_enabled', 'false'::jsonb),
  ('whatsapp_notify_new_business', 'true'::jsonb),
  ('whatsapp_notify_business_changes', 'true'::jsonb),
  ('whatsapp_notify_user_reports', 'true'::jsonb)
on conflict (key) do nothing;

create or replace function public.admin_update_whatsapp_settings(
  p_number text,
  p_enabled boolean,
  p_new_business boolean,
  p_changes boolean,
  p_reports boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  clean_number text := regexp_replace(coalesce(p_number, ''), '[^0-9]', '', 'g');
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required';
  end if;
  if p_enabled and length(clean_number) not between 8 and 15 then
    raise exception 'valid WhatsApp number required';
  end if;

  update public.system_settings
  set value = case key
    when 'admin_whatsapp_number' then to_jsonb(clean_number)
    when 'whatsapp_notifications_enabled' then to_jsonb(p_enabled)
    when 'whatsapp_notify_new_business' then to_jsonb(p_new_business)
    when 'whatsapp_notify_business_changes' then to_jsonb(p_changes)
    when 'whatsapp_notify_user_reports' then to_jsonb(p_reports)
  end,
  updated_at = now(),
  updated_by = auth.uid()
  where key in (
    'admin_whatsapp_number', 'whatsapp_notifications_enabled',
    'whatsapp_notify_new_business', 'whatsapp_notify_business_changes',
    'whatsapp_notify_user_reports'
  );
end;
$$;

revoke all on function public.admin_update_whatsapp_settings(
  text, boolean, boolean, boolean, boolean
) from public;
grant execute on function public.admin_update_whatsapp_settings(
  text, boolean, boolean, boolean, boolean
) to authenticated;

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  event_type text not null check (event_type in (
    'PROFILE_VIEW', 'CLICK_PHONE', 'CLICK_WHATSAPP',
    'SAVE_BUSINESS', 'REQUEST_CONTACT'
  )),
  created_at timestamptz not null default now()
);

create index if not exists analytics_events_business_created_idx
  on public.analytics_events (business_id, created_at desc);
create index if not exists analytics_events_type_created_idx
  on public.analytics_events (event_type, created_at desc);

alter table public.analytics_events enable row level security;

create policy "admins read analytics events" on public.analytics_events
for select to authenticated using (public.current_user_is_admin());

grant select on public.analytics_events to authenticated;

create or replace function public.record_business_analytics_event(
  p_business_id uuid,
  p_event_type text
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_event_type not in (
    'PROFILE_VIEW', 'CLICK_PHONE', 'CLICK_WHATSAPP',
    'SAVE_BUSINESS', 'REQUEST_CONTACT'
  ) then
    raise exception 'unsupported analytics event';
  end if;

  if not exists (
    select 1 from public.businesses
    where id = p_business_id and publication_status = 'published'
  ) then
    return;
  end if;

  insert into public.analytics_events (business_id, user_id, event_type)
  values (p_business_id, auth.uid(), p_event_type);
end;
$$;

revoke all on function public.record_business_analytics_event(uuid, text)
from public;
grant execute on function public.record_business_analytics_event(uuid, text)
to anon, authenticated;

create or replace function public.admin_analytics_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required';
  end if;

  select jsonb_build_object(
    'PROFILE_VIEW', count(*) filter (where event_type = 'PROFILE_VIEW'),
    'CLICK_PHONE', count(*) filter (where event_type = 'CLICK_PHONE'),
    'CLICK_WHATSAPP', count(*) filter (where event_type = 'CLICK_WHATSAPP'),
    'SAVE_BUSINESS', count(*) filter (where event_type = 'SAVE_BUSINESS'),
    'REQUEST_CONTACT', count(*) filter (where event_type = 'REQUEST_CONTACT')
  ) into result
  from public.analytics_events
  where created_at >= now() - interval '30 days';

  return result;
end;
$$;

revoke all on function public.admin_analytics_summary() from public;
grant execute on function public.admin_analytics_summary() to authenticated;

-- A provider may read only the configured WhatsApp destination for their
-- own submitted business. Opening the link still requires a human to send it.
create or replace function public.review_whatsapp_details(p_business_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
  review_event text;
begin
  if auth.uid() is null then
    return null;
  end if;

  if not exists (
    select 1 from public.system_settings
    where key = 'whatsapp_notifications_enabled' and value = 'true'::jsonb
  ) then
    return null;
  end if;

  select bre.event_type into review_event
  from public.business_review_events bre
  where bre.business_id = p_business_id
    and bre.event_type in ('submitted', 'resubmitted')
  order by bre.created_at desc
  limit 1;

  if not exists (
    select 1 from public.system_settings
    where key = case when review_event = 'resubmitted'
      then 'whatsapp_notify_business_changes'
      else 'whatsapp_notify_new_business' end
      and value = 'true'::jsonb
  ) then
    return null;
  end if;

  select jsonb_build_object(
    'number', (select value #>> '{}' from public.system_settings
               where key = 'admin_whatsapp_number'),
    'business_name', b.name,
    'event_type', coalesce(review_event, 'submitted'),
    'category', coalesce(c.name, b.business_type::text),
    'location', coalesce((
      select l.name from public.business_coverage bc
      join public.locations l on l.id = bc.location_id
      where bc.business_id = b.id
      order by l.name limit 1
    ), '')
  ) into result
  from public.businesses b
  left join public.categories c on c.id = b.primary_category_id
  where b.id = p_business_id
    and b.owner_id = auth.uid()
    and b.publication_status = 'pending_review';

  return result;
end;
$$;

revoke all on function public.review_whatsapp_details(uuid) from public;
grant execute on function public.review_whatsapp_details(uuid) to authenticated;
