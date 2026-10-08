-- Durable contact throttling and idempotency. The Edge Function calls the
-- single SECURITY DEFINER RPC with validated fields; API roles cannot access
-- the control tables or invoke this RPC directly.

alter table public.contact_messages
  add column if not exists idempotency_key uuid;

create unique index if not exists contact_messages_idempotency_key_uidx
  on public.contact_messages (idempotency_key)
  where idempotency_key is not null;

create table if not exists public.contact_submission_rate_limits (
  identity_hash text primary key
    check (identity_hash ~ '^[0-9a-f]{64}$'),
  window_started_at timestamptz not null,
  request_count integer not null check (request_count > 0)
);
create index if not exists contact_submission_rate_limits_window_idx
  on public.contact_submission_rate_limits (window_started_at);

create table if not exists public.contact_submission_dedup (
  fingerprint text primary key
    check (fingerprint ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz not null
);
create index if not exists contact_submission_dedup_expires_idx
  on public.contact_submission_dedup (expires_at);

alter table public.contact_submission_rate_limits enable row level security;
alter table public.contact_submission_dedup enable row level security;
revoke all on public.contact_submission_rate_limits
  from public, anon, authenticated, service_role;
revoke all on public.contact_submission_dedup
  from public, anon, authenticated, service_role;

create or replace function public.submit_contact_message_with_controls(
  p_name text,
  p_email text,
  p_subject text,
  p_message text,
  p_user_id uuid,
  p_idempotency_key uuid,
  p_ip_hash text,
  p_user_hash text,
  p_email_hash text,
  p_fingerprint text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_identity text;
  v_count integer;
  v_started timestamptz;
  v_limit integer;
begin
  if p_idempotency_key is null
     or p_fingerprint is null
     or p_email_hash is null
     or p_fingerprint !~ '^[0-9a-f]{64}$'
     or p_email_hash !~ '^[0-9a-f]{64}$'
     or (p_ip_hash is not null and p_ip_hash !~ '^[0-9a-f]{64}$')
     or (p_user_hash is not null and p_user_hash !~ '^[0-9a-f]{64}$') then
    raise exception 'INVALID_CONTACT_CONTROL_INPUT' using errcode = '22023';
  end if;

  -- Stable lock ordering serializes the same identity/fingerprint safely.
  perform pg_advisory_xact_lock(hashtextextended(k.lock_key, 0))
  from (
    select distinct x as lock_key
    from unnest(array[p_ip_hash, p_user_hash, p_email_hash]) x
    where x is not null
    union
    select 'dedup:' || p_fingerprint
    union
    select 'idempotency:' || p_idempotency_key::text
    order by 1
  ) k;

  if exists (select 1 from public.contact_messages
      where idempotency_key = p_idempotency_key) then
    return 'duplicate';
  end if;
  if exists (select 1 from public.contact_submission_dedup
      where fingerprint = p_fingerprint and expires_at > now()) then
    return 'duplicate';
  end if;

  -- Bounded opportunistic cleanup; hashed identifiers only, never raw IP/email.
  with expired as (
    select ctid from public.contact_submission_rate_limits
    where window_started_at < now() - interval '24 hours'
    order by window_started_at limit 500 for update skip locked
  )
  delete from public.contact_submission_rate_limits t using expired e
  where t.ctid = e.ctid;
  with expired as (
    select ctid from public.contact_submission_dedup
    where expires_at < now()
    order by expires_at limit 500 for update skip locked
  )
  delete from public.contact_submission_dedup t using expired e
  where t.ctid = e.ctid;

  for v_identity in
    select distinct x from unnest(array[p_ip_hash, p_user_hash, p_email_hash]) x
    where x is not null order by x
  loop
    v_limit := case when v_identity = p_ip_hash then 10 else 3 end;
    select request_count, window_started_at
      into v_count, v_started
    from public.contact_submission_rate_limits
    where identity_hash = v_identity;
    if found and v_started > now() - interval '1 hour'
       and v_count >= v_limit then
      return 'rate_limited';
    end if;
  end loop;

  for v_identity in
    select distinct x from unnest(array[p_ip_hash, p_user_hash, p_email_hash]) x
    where x is not null order by x
  loop
    insert into public.contact_submission_rate_limits
      (identity_hash, window_started_at, request_count)
    values (v_identity, now(), 1)
    on conflict (identity_hash) do update
    set window_started_at = case
          when public.contact_submission_rate_limits.window_started_at
            <= now() - interval '1 hour' then now()
          else public.contact_submission_rate_limits.window_started_at end,
        request_count = case
          when public.contact_submission_rate_limits.window_started_at
            <= now() - interval '1 hour' then 1
          else public.contact_submission_rate_limits.request_count + 1 end;
  end loop;

  insert into public.contact_submission_dedup (fingerprint, expires_at)
  values (p_fingerprint, now() + interval '10 minutes')
  on conflict (fingerprint) do update
  set expires_at = excluded.expires_at;
  insert into public.contact_messages
    (name, email, subject, message, user_id, idempotency_key)
  values (p_name, p_email, p_subject, p_message, p_user_id, p_idempotency_key);
  return 'created';
end;
$$;

revoke all on function public.submit_contact_message_with_controls(
  text, text, text, text, uuid, uuid, text, text, text, text
) from public, anon, authenticated, service_role;
grant execute on function public.submit_contact_message_with_controls(
  text, text, text, text, uuid, uuid, text, text, text, text
) to service_role;

do $$
begin
  if has_function_privilege('anon',
       'public.submit_contact_message_with_controls(text,text,text,text,uuid,uuid,text,text,text,text)',
       'EXECUTE')
     or has_function_privilege('authenticated',
       'public.submit_contact_message_with_controls(text,text,text,text,uuid,uuid,text,text,text,text)',
       'EXECUTE')
     or has_table_privilege('anon', 'public.contact_submission_rate_limits', 'SELECT')
     or has_table_privilege('authenticated', 'public.contact_submission_rate_limits', 'SELECT')
     or has_table_privilege('anon', 'public.contact_submission_rate_limits', 'INSERT')
     or has_table_privilege('authenticated', 'public.contact_submission_rate_limits', 'INSERT')
     or has_table_privilege('anon', 'public.contact_submission_dedup', 'SELECT')
     or has_table_privilege('authenticated', 'public.contact_submission_dedup', 'SELECT')
     or has_table_privilege('anon', 'public.contact_submission_rate_limits', 'UPDATE')
     or has_table_privilege('authenticated', 'public.contact_submission_rate_limits', 'DELETE')
     or has_table_privilege('anon', 'public.contact_submission_dedup', 'INSERT')
     or has_table_privilege('authenticated', 'public.contact_submission_dedup', 'UPDATE')
     or has_table_privilege('service_role', 'public.contact_submission_rate_limits', 'SELECT')
     or has_table_privilege('service_role', 'public.contact_submission_dedup', 'INSERT') then
    raise exception 'contact controls are exposed directly to API roles';
  end if;
  if not has_function_privilege('service_role',
       'public.submit_contact_message_with_controls(text,text,text,text,uuid,uuid,text,text,text,text)',
       'EXECUTE') then
    raise exception 'service_role cannot execute contact controls';
  end if;
end;
$$;
