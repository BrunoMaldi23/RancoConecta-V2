-- Public contact channels and only the administrative notice types that
-- existing database triggers actually emit.
insert into public.system_settings (key, value) values
  ('support_email', to_jsonb(''::text)),
  ('support_whatsapp', to_jsonb(''::text)),
  ('notify_new_business', 'true'::jsonb),
  ('notify_business_changes', 'true'::jsonb),
  ('notify_contact_message', 'true'::jsonb)
on conflict (key) do nothing;

create or replace function public.public_contact_channels()
returns jsonb language sql stable security definer
set search_path = pg_catalog
as $$
  select jsonb_build_object(
    'email', coalesce((select value #>> '{}' from public.system_settings
      where key = 'support_email'), ''),
    'whatsapp', coalesce((select value #>> '{}' from public.system_settings
      where key = 'support_whatsapp'), '')
  );
$$;
revoke all on function public.public_contact_channels() from public;
grant execute on function public.public_contact_channels() to anon, authenticated;

create or replace function public.admin_update_contact_channels(
  p_email text, p_whatsapp text
)
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_whatsapp text := btrim(coalesce(p_whatsapp, ''));
  v_old jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if char_length(v_email) > 254 or (v_email <> '' and
      v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$') or
      (v_whatsapp <> '' and v_whatsapp !~ '^\+?[1-9][0-9]{7,14}$') then
    raise exception 'INVALID_CONTACT_CHANNEL' using errcode = '22023';
  end if;
  v_whatsapp := ltrim(v_whatsapp, '+');
  select public.public_contact_channels() into v_old;
  update public.system_settings
  set value = case key
    when 'support_email' then to_jsonb(v_email)
    else to_jsonb(v_whatsapp) end,
    updated_at = now(), updated_by = auth.uid()
  where key in ('support_email', 'support_whatsapp');
  if v_old is distinct from public.public_contact_channels() then
    insert into public.audit_logs
      (actor_id, action, entity_type, old_data, new_data)
    values (auth.uid(), 'admin_settings_updated', 'system_settings',
      v_old, public.public_contact_channels());
  end if;
end;
$$;
revoke all on function public.admin_update_contact_channels(text, text)
from public, anon, authenticated;
grant execute on function public.admin_update_contact_channels(text, text)
to authenticated;

create or replace function public.admin_update_notification_settings(
  p_new_business boolean, p_business_changes boolean,
  p_contact_message boolean
)
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_old jsonb;
  v_new jsonb;
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_new_business is null or p_business_changes is null or
     p_contact_message is null then
    raise exception 'INVALID_NOTIFICATION_SETTINGS' using errcode = '22023';
  end if;
  select jsonb_object_agg(key, value) into v_old from public.system_settings
  where key in ('notify_new_business', 'notify_business_changes',
    'notify_contact_message');
  update public.system_settings
  set value = case key
    when 'notify_new_business' then to_jsonb(p_new_business)
    when 'notify_business_changes' then to_jsonb(p_business_changes)
    else to_jsonb(p_contact_message) end,
    updated_at = now(), updated_by = auth.uid()
  where key in ('notify_new_business', 'notify_business_changes',
    'notify_contact_message');
  select jsonb_object_agg(key, value) into v_new from public.system_settings
  where key in ('notify_new_business', 'notify_business_changes',
    'notify_contact_message');
  if v_old is distinct from v_new then
    insert into public.audit_logs
      (actor_id, action, entity_type, old_data, new_data)
    values (auth.uid(), 'admin_settings_updated', 'system_settings',
      v_old, v_new);
  end if;
end;
$$;
revoke all on function public.admin_update_notification_settings(
  boolean, boolean, boolean) from public, anon, authenticated;
grant execute on function public.admin_update_notification_settings(
  boolean, boolean, boolean) to authenticated;

create or replace function public.notify_admins_on_business_review()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_key text;
begin
  if new.publication_status = 'pending_review'
     and old.publication_status is distinct from 'pending_review' then
    v_key := case when old.publication_status = 'draft'
      then 'notify_new_business' else 'notify_business_changes' end;
    if coalesce((select value = 'true'::jsonb from public.system_settings
      where key = v_key), true) then
      insert into public.notifications
        (user_id, type, title, body, entity_type, entity_id, deep_link)
      select p.id,
        case when v_key = 'notify_new_business' then 'provider_pending_review'
          else 'provider_changes_review' end,
        case when v_key = 'notify_new_business'
          then 'Nuevo negocio pendiente de revisión'
          else 'Cambios de negocio pendientes de revisión' end,
        'Negocio pendiente: ' || new.name,
        'business', new.id, '/admin/businesses/' || new.id::text
      from public.profiles p
      where p.role in ('admin', 'super_admin') and p.account_status = 'active'
      on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.notify_admins_on_contact_message()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  if coalesce((select value = 'true'::jsonb from public.system_settings
    where key = 'notify_contact_message'), true) then
    insert into public.notifications
      (user_id, type, title, body, entity_type, entity_id)
    select p.id, 'contact_message', 'Nuevo mensaje de contacto',
      'Hay una nueva consulta para revisar.', 'contact_message', new.id
    from public.profiles p
    where p.role in ('admin', 'super_admin') and p.account_status = 'active';
  end if;
  return new;
end;
$$;
