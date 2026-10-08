-- Public contact submissions are accepted only by the validated Edge Function.
create table if not exists public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 3 and 120),
  email text not null check (char_length(email) between 5 and 254),
  subject text not null check (subject in (
    'Consulta general', 'Problema con mi cuenta', 'Negocio o publicación',
    'Privacidad y datos', 'Otro'
  )),
  message text not null check (char_length(message) between 10 and 4000),
  user_id uuid references public.profiles(id) on delete set null,
  status text not null default 'new'
    check (status in ('new', 'in_review', 'resolved')),
  created_at timestamptz not null default now()
);

create index if not exists contact_messages_status_created_idx
on public.contact_messages (status, created_at desc);

alter table public.contact_messages enable row level security;
revoke all on public.contact_messages from public, anon, authenticated;
grant select on public.contact_messages to authenticated;
create policy "active admins read contact messages" on public.contact_messages
for select to authenticated using (public.current_user_is_admin());

create or replace function public.admin_set_contact_message_status(
  p_message_id uuid, p_status text
)
returns void language plpgsql security definer
set search_path = pg_catalog
as $$
declare
  v_old text;
begin
  if not public.current_user_is_admin() then
    raise exception 'admin access required' using errcode = '42501';
  end if;
  if p_message_id is null or p_status not in ('new', 'in_review', 'resolved') then
    raise exception 'INVALID_CONTACT_STATUS' using errcode = '22023';
  end if;
  select status into v_old from public.contact_messages
  where id = p_message_id for update;
  if not found then
    raise exception 'CONTACT_MESSAGE_NOT_FOUND' using errcode = '22023';
  end if;
  if v_old = p_status then return; end if;
  update public.contact_messages set status = p_status where id = p_message_id;
  insert into public.audit_logs
    (actor_id, action, entity_type, entity_id, old_data, new_data)
  values (auth.uid(), 'contact_message_status_changed', 'contact_message',
    p_message_id, jsonb_build_object('status', v_old),
    jsonb_build_object('status', p_status));
end;
$$;
revoke all on function public.admin_set_contact_message_status(uuid, text)
from public, anon, authenticated;
grant execute on function public.admin_set_contact_message_status(uuid, text)
to authenticated;

create or replace function public.notify_admins_on_contact_message()
returns trigger language plpgsql security definer
set search_path = pg_catalog
as $$
begin
  insert into public.notifications (
    user_id, type, title, body, entity_type, entity_id
  )
  select p.id, 'contact_message', 'Nuevo mensaje de contacto',
    'Hay una nueva consulta para revisar.', 'contact_message', new.id
  from public.profiles p
  where p.role in ('admin', 'super_admin')
    and p.account_status = 'active';
  return new;
end;
$$;

revoke all on function public.notify_admins_on_contact_message()
from public, anon, authenticated;
drop trigger if exists notify_admins_on_contact_message
on public.contact_messages;
create trigger notify_admins_on_contact_message
after insert on public.contact_messages
for each row execute function public.notify_admins_on_contact_message();
