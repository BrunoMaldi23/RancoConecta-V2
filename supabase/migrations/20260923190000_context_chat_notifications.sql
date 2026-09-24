-- ============================================================
-- RANCO CONECTA V2
-- Contextual chat, unread state, notifications and realtime
-- ============================================================

alter table public.notifications
  add column if not exists deep_link text,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

alter table public.conversations
  add column if not exists context_type text,
  add column if not exists context_id uuid,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists last_message_at timestamptz,
  add column if not exists last_message_preview text;

alter table public.conversations
  alter column request_id drop not null;

update public.conversations
set
  context_type = coalesce(context_type, 'service_request'),
  context_id = coalesce(context_id, request_id),
  updated_at = coalesce(updated_at, created_at)
where context_type is null or context_id is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'conversations_context_required'
      and conrelid = 'public.conversations'::regclass
  ) then
    alter table public.conversations
      add constraint conversations_context_required
      check (
        (context_type is null and context_id is null)
        or context_type in ('service_request', 'operation', 'lodging_booking', 'support_ticket')
      );
  end if;
end;
$$;

create unique index if not exists conversations_context_unique_idx
  on public.conversations(context_type, context_id)
  where context_type is not null and context_id is not null;

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  context_role text not null default 'participant',
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);

alter table public.conversation_members enable row level security;

insert into public.conversation_members (
  conversation_id,
  user_id,
  context_role,
  last_read_at
)
select
  c.id,
  c.customer_id,
  'customer',
  c.created_at
from public.conversations c
on conflict (conversation_id, user_id) do nothing;

insert into public.conversation_members (
  conversation_id,
  user_id,
  context_role
)
select
  c.id,
  bm.user_id,
  'provider'
from public.conversations c
join public.business_members bm on bm.business_id = c.business_id
where bm.status = 'active'
  and bm.role in ('owner', 'manager')
on conflict (conversation_id, user_id) do nothing;

create or replace function public.context_chat_participants(
  p_context_type text,
  p_context_id uuid
)
returns table(user_id uuid, context_role text)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if p_context_type = 'service_request' then
    return query
    select sr.customer_id, 'customer'::text
    from public.service_requests sr
    where sr.id = p_context_id
    union
    select bm.user_id, 'provider'::text
    from public.service_requests sr
    join public.business_members bm on bm.business_id = sr.business_id
    where sr.id = p_context_id
      and bm.status = 'active'
      and bm.role in ('owner', 'manager');
    return;
  end if;

  if p_context_type = 'operation' then
    return query
    select o.customer_id, 'customer'::text
    from public.operations o
    where o.id = p_context_id
    union
    select bm.user_id, 'provider'::text
    from public.operations o
    join public.business_members bm on bm.business_id = o.business_id
    where o.id = p_context_id
      and bm.status = 'active'
      and bm.role in ('owner', 'manager');
    return;
  end if;

  if p_context_type = 'lodging_booking' then
    return query
    select lb.guest_user_id, 'guest'::text
    from public.lodging_bookings lb
    where lb.id = p_context_id
    union
    select bm.user_id, 'provider'::text
    from public.lodging_bookings lb
    join public.business_members bm on bm.business_id = lb.business_id
    where lb.id = p_context_id
      and bm.status = 'active'
      and bm.role in ('owner', 'manager');
    return;
  end if;
end;
$$;

create or replace function public.user_can_access_conversation(
  p_conversation_id uuid
)
returns boolean
language sql
security definer
set search_path = public, auth
stable
as $$
  select auth.uid() is not null and (
    exists (
      select 1
      from public.conversation_members cm
      where cm.conversation_id = p_conversation_id
        and cm.user_id = auth.uid()
    )
    or public.is_admin()
  );
$$;

create or replace function public.sync_context_conversation_members(
  p_conversation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_conversation public.conversations%rowtype;
begin
  select * into v_conversation
  from public.conversations
  where id = p_conversation_id;

  if not found then
    raise exception 'conversation not found';
  end if;

  insert into public.conversation_members (
    conversation_id,
    user_id,
    context_role
  )
  select
    p_conversation_id,
    participants.user_id,
    participants.context_role
  from public.context_chat_participants(
    coalesce(v_conversation.context_type, 'service_request'),
    coalesce(v_conversation.context_id, v_conversation.request_id)
  ) participants
  on conflict (conversation_id, user_id) do update
    set context_role = excluded.context_role;
end;
$$;

create or replace function public.get_or_create_context_conversation(
  p_context_type text,
  p_context_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_request_id uuid;
  v_customer_id uuid;
  v_business_id uuid;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if p_context_type not in ('service_request', 'operation', 'lodging_booking') then
    raise exception 'unsupported conversation context';
  end if;

  if not exists (
    select 1
    from public.context_chat_participants(p_context_type, p_context_id) participants
    where participants.user_id = auth.uid()
  ) and not public.is_admin() then
    raise exception 'not authorized';
  end if;

  if p_context_type = 'service_request' then
    select sr.id, sr.customer_id, sr.business_id
    into v_request_id, v_customer_id, v_business_id
    from public.service_requests sr
    where sr.id = p_context_id;
  elsif p_context_type = 'operation' then
    select o.request_id, o.customer_id, o.business_id
    into v_request_id, v_customer_id, v_business_id
    from public.operations o
    where o.id = p_context_id;
  elsif p_context_type = 'lodging_booking' then
    select null::uuid, lb.guest_user_id, lb.business_id
    into v_request_id, v_customer_id, v_business_id
    from public.lodging_bookings lb
    where lb.id = p_context_id;
  end if;

  if v_customer_id is null or v_business_id is null then
    raise exception 'conversation context is incomplete';
  end if;

  insert into public.conversations (
    request_id,
    customer_id,
    business_id,
    context_type,
    context_id,
    updated_at
  )
  values (
    v_request_id,
    v_customer_id,
    v_business_id,
    p_context_type,
    p_context_id,
    now()
  )
  on conflict (context_type, context_id) where context_type is not null and context_id is not null
  do update set updated_at = public.conversations.updated_at
  returning id into v_conversation_id;

  perform public.sync_context_conversation_members(v_conversation_id);

  return v_conversation_id;
end;
$$;

create or replace function public.send_message(
  p_conversation_id uuid,
  p_body text
)
returns public.messages
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_body text := nullif(trim(coalesce(p_body, '')), '');
  v_message public.messages%rowtype;
  v_preview text;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_access_conversation(p_conversation_id) then
    raise exception 'not authorized';
  end if;

  if v_body is null then
    raise exception 'message body is required';
  end if;

  if length(v_body) > 2000 then
    raise exception 'message body is too long';
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    message_type,
    text
  )
  values (
    p_conversation_id,
    auth.uid(),
    'text',
    v_body
  )
  returning * into v_message;

  v_preview := left(v_body, 140);

  update public.conversations
  set
    last_message_at = v_message.created_at,
    last_message_preview = v_preview,
    updated_at = v_message.created_at
  where id = p_conversation_id;

  update public.conversation_members
  set last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = auth.uid();

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    deep_link,
    metadata
  )
  select
    cm.user_id,
    'new_message',
    'Nuevo mensaje',
    'Tienes un nuevo mensaje en Ranco Conecta.',
    'conversation',
    p_conversation_id,
    '/messages/' || p_conversation_id::text,
    jsonb_build_object('conversation_id', p_conversation_id)
  from public.conversation_members cm
  where cm.conversation_id = p_conversation_id
    and cm.user_id <> auth.uid();

  return v_message;
end;
$$;

create or replace function public.mark_conversation_read(
  p_conversation_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if not public.user_can_access_conversation(p_conversation_id) then
    raise exception 'not authorized';
  end if;

  update public.conversation_members
  set last_read_at = now()
  where conversation_id = p_conversation_id
    and user_id = auth.uid();
end;
$$;

create or replace function public.conversation_list()
returns table(
  id uuid,
  context_type text,
  context_id uuid,
  request_id uuid,
  title text,
  preview text,
  last_message_at timestamptz,
  unread_count integer
)
language sql
security definer
set search_path = public, auth
stable
as $$
  select
    c.id,
    coalesce(c.context_type, 'service_request') as context_type,
    coalesce(c.context_id, c.request_id) as context_id,
    c.request_id,
    coalesce(b.name, sr.public_code, 'Conversación') as title,
    coalesce(c.last_message_preview, sr.description, 'Sin mensajes todavía') as preview,
    coalesce(c.last_message_at, c.updated_at, c.created_at) as last_message_at,
    count(m.id)::integer as unread_count
  from public.conversations c
  join public.conversation_members cm
    on cm.conversation_id = c.id
   and cm.user_id = auth.uid()
  left join public.service_requests sr on sr.id = c.request_id
  left join public.businesses b on b.id = c.business_id
  left join public.messages m
    on m.conversation_id = c.id
   and m.sender_id <> auth.uid()
   and (cm.last_read_at is null or m.created_at > cm.last_read_at)
  group by c.id, sr.public_code, sr.description, b.name
  order by coalesce(c.last_message_at, c.updated_at, c.created_at) desc;
$$;

create or replace function public.conversation_messages(
  p_conversation_id uuid,
  p_limit integer default 80,
  p_before timestamptz default null
)
returns table(
  id uuid,
  conversation_id uuid,
  sender_id uuid,
  sender_name text,
  message_type text,
  body text,
  attachment_path text,
  created_at timestamptz,
  is_mine boolean
)
language sql
security definer
set search_path = public, auth
stable
as $$
  select
    m.id,
    m.conversation_id,
    m.sender_id,
    coalesce(p.full_name, 'Usuario') as sender_name,
    m.message_type::text,
    m.text as body,
    m.attachment_path,
    m.created_at,
    m.sender_id = auth.uid() as is_mine
  from public.messages m
  left join public.profiles p on p.id = m.sender_id
  where m.conversation_id = p_conversation_id
    and public.user_can_access_conversation(p_conversation_id)
    and (p_before is null or m.created_at < p_before)
  order by m.created_at desc
  limit greatest(1, least(coalesce(p_limit, 80), 120));
$$;

create or replace function public.unread_conversation_count()
returns integer
language sql
security definer
set search_path = public, auth
stable
as $$
  select coalesce(sum(item.unread_count), 0)::integer
  from public.conversation_list() item;
$$;

create or replace function public.notification_list()
returns table(
  id uuid,
  type text,
  title text,
  body text,
  entity_type text,
  entity_id uuid,
  deep_link text,
  metadata jsonb,
  read_at timestamptz,
  created_at timestamptz
)
language sql
security definer
set search_path = public, auth
stable
as $$
  select
    n.id,
    n.type,
    n.title,
    n.body,
    n.entity_type,
    n.entity_id,
    coalesce(
      n.deep_link,
      case
        when n.entity_type = 'conversation' then '/messages/' || n.entity_id::text
        when n.entity_type = 'service_request' then '/requests/' || n.entity_id::text
        when n.entity_type = 'operation' then '/requests'
        when n.entity_type = 'quote' then '/requests'
        else null
      end
    ) as deep_link,
    n.metadata,
    n.read_at,
    n.created_at
  from public.notifications n
  where n.user_id = auth.uid()
  order by n.created_at desc
  limit 100;
$$;

create or replace function public.mark_notification_read(
  p_notification_id uuid
)
returns void
language sql
security definer
set search_path = public, auth
as $$
  update public.notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and user_id = auth.uid();
$$;

create or replace function public.mark_all_notifications_read()
returns void
language sql
security definer
set search_path = public, auth
as $$
  update public.notifications
  set read_at = coalesce(read_at, now())
  where user_id = auth.uid()
    and read_at is null;
$$;

create or replace function public.unread_notification_count()
returns integer
language sql
security definer
set search_path = public, auth
stable
as $$
  select count(*)::integer
  from public.notifications n
  where n.user_id = auth.uid()
    and n.read_at is null;
$$;

drop policy if exists "conversation participants read conversations" on public.conversations;
drop policy if exists "conversation participants read messages" on public.messages;
drop policy if exists "conversation participants create messages" on public.messages;
drop policy if exists "conversation members read memberships" on public.conversation_members;
drop policy if exists "conversation members read conversations" on public.conversations;
drop policy if exists "conversation members read messages" on public.messages;

create policy "conversation members read memberships"
on public.conversation_members
for select
using (user_id = auth.uid() or public.is_admin());

create policy "conversation members read conversations"
on public.conversations
for select
using (public.user_can_access_conversation(id));

create policy "conversation members read messages"
on public.messages
for select
using (public.user_can_access_conversation(conversation_id));

create or replace function public.accept_quote(
  p_quote_id uuid
)
returns public.operations
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_quote public.quotes%rowtype;
  v_request public.service_requests%rowtype;
  v_operation public.operations%rowtype;
  v_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  select * into v_quote
  from public.quotes
  where id = p_quote_id
  for update;

  if not found then
    raise exception 'quote not found';
  end if;

  select * into v_request
  from public.service_requests
  where id = v_quote.request_id
  for update;

  if not found then
    raise exception 'request not found';
  end if;

  if v_request.customer_id <> auth.uid() then
    raise exception 'not authorized';
  end if;

  select * into v_operation
  from public.operations
  where request_id = v_request.id
  for update;

  if found then
    perform public.get_or_create_context_conversation('service_request', v_request.id);
    return v_operation;
  end if;

  if v_quote.status::text <> 'pending' then
    raise exception 'quote already responded';
  end if;

  if v_request.status::text not in ('quoted', 'viewed', 'submitted') then
    raise exception 'request no longer accepts quotes';
  end if;

  update public.quotes
  set status = 'accepted'
  where id = v_quote.id
  returning * into v_quote;

  update public.quotes
  set status = 'rejected'
  where request_id = v_request.id
    and id <> v_quote.id
    and status = 'pending';

  update public.service_requests
  set
    status = 'accepted',
    business_id = v_quote.business_id
  where id = v_request.id
  returning * into v_request;

  insert into public.operations (
    type,
    customer_id,
    business_id,
    request_id,
    quote_id,
    status,
    subtotal,
    total,
    payment_status
  )
  values (
    'service',
    v_request.customer_id,
    v_quote.business_id,
    v_request.id,
    v_quote.id,
    'accepted',
    v_quote.total_amount,
    v_quote.total_amount,
    'not_required'
  )
  returning * into v_operation;

  insert into public.operation_events (
    operation_id,
    event_type,
    actor_id,
    previous_status,
    new_status,
    metadata
  )
  values (
    v_operation.id,
    'operation_created',
    auth.uid(),
    null,
    'accepted',
    jsonb_build_object('quote_id', v_quote.id, 'request_id', v_request.id)
  );

  v_conversation_id := public.get_or_create_context_conversation(
    'service_request',
    v_request.id
  );

  insert into public.notifications (
    user_id,
    type,
    title,
    body,
    entity_type,
    entity_id,
    deep_link,
    metadata
  )
  select
    bm.user_id,
    'quote_accepted',
    'Cotización aceptada',
    'Una cotización de tu negocio fue aceptada.',
    'operation',
    v_operation.id,
    '/messages/' || v_conversation_id::text,
    jsonb_build_object(
      'operation_id', v_operation.id,
      'request_id', v_request.id,
      'conversation_id', v_conversation_id
    )
  from public.business_members bm
  where bm.business_id = v_quote.business_id
    and bm.status = 'active'
    and bm.role in ('owner', 'manager');

  return v_operation;
end;
$$;

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'messages'
    ) then
      alter publication supabase_realtime add table public.messages;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'conversations'
    ) then
      alter publication supabase_realtime add table public.conversations;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'conversation_members'
    ) then
      alter publication supabase_realtime add table public.conversation_members;
    end if;

    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'notifications'
    ) then
      alter publication supabase_realtime add table public.notifications;
    end if;
  end if;
end;
$$;

grant execute on function public.context_chat_participants(text, uuid) to authenticated;
grant execute on function public.user_can_access_conversation(uuid) to authenticated;
grant execute on function public.sync_context_conversation_members(uuid) to authenticated;
grant execute on function public.get_or_create_context_conversation(text, uuid) to authenticated;
grant execute on function public.send_message(uuid, text) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.conversation_list() to authenticated;
grant execute on function public.conversation_messages(uuid, integer, timestamptz) to authenticated;
grant execute on function public.unread_conversation_count() to authenticated;
grant execute on function public.notification_list() to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
grant execute on function public.unread_notification_count() to authenticated;
