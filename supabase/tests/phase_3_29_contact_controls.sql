-- Requires contact_messages and migration 20261007190000. Rollback-only contract.
begin;

do $$
declare
  v_id uuid := gen_random_uuid();
  v_status text;
  v_email_hash text := repeat('a', 64);
  v_ip_hash text := repeat('b', 64);
  v_fingerprint text := repeat('c', 64);
  v_second_fingerprint text := repeat('d', 64);
  v_fourth_fingerprint text := repeat('e', 64);
  v_user_hash text := repeat('9', 64);
begin
  if has_function_privilege('anon',
       'public.submit_contact_message_with_controls(text,text,text,text,uuid,uuid,text,text,text,text)',
       'EXECUTE')
     or has_function_privilege('authenticated',
       'public.submit_contact_message_with_controls(text,text,text,text,uuid,uuid,text,text,text,text)',
       'EXECUTE') then
    raise exception 'contact submission control RPC is exposed to API roles';
  end if;
  if has_table_privilege('anon', 'public.contact_messages', 'INSERT')
     or has_table_privilege('authenticated', 'public.contact_messages', 'INSERT') then
    raise exception 'API roles can bypass submit-contact via direct table insert';
  end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Mensaje de contacto QA para validar el rate limit.', null, v_id,
    v_ip_hash, null, v_email_hash, v_fingerprint);
  if v_status <> 'created' then raise exception 'valid message was not created'; end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Mensaje de contacto QA para validar el rate limit.', null, v_id,
    v_ip_hash, null, v_email_hash, v_fingerprint);
  if v_status <> 'duplicate' then raise exception 'same idempotency key was not deduplicated'; end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Mensaje de contacto QA para validar el rate limit.', null, gen_random_uuid(),
    v_ip_hash, null, v_email_hash, v_fingerprint);
  if v_status <> 'duplicate' then raise exception 'same content was not deduplicated'; end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Segundo mensaje diferente para la comprobacion.', null, gen_random_uuid(),
    v_ip_hash, null, v_email_hash, v_second_fingerprint);
  if v_status <> 'created' then raise exception 'second message unexpectedly blocked'; end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Tercer mensaje diferente para la comprobacion.', null, gen_random_uuid(),
    v_ip_hash, null, v_email_hash, v_fourth_fingerprint);
  if v_status <> 'created' then raise exception 'third message unexpectedly blocked'; end if;

  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Cuarto mensaje diferente debe superar el limite.', null, gen_random_uuid(),
    v_ip_hash, null, v_email_hash, repeat('f', 64));
  if v_status <> 'rate_limited' then raise exception 'email rate limit did not activate'; end if;

  update public.contact_submission_rate_limits
  set window_started_at = now() - interval '2 hours'
  where identity_hash = v_email_hash;
  v_status := public.submit_contact_message_with_controls(
    'QA Test', 'qa-contact@example.test', 'Otro',
    'Mensaje despues de expirar la ventana configurada.', null, gen_random_uuid(),
    v_ip_hash, null, v_email_hash, repeat('1', 64));
  if v_status <> 'created' then raise exception 'expired window did not reset limit'; end if;

  -- Authenticated identity bucket is tested separately from the email bucket.
  v_status := public.submit_contact_message_with_controls(
    'QA User', 'signed-in-1@example.test', 'Otro', 'Primer mensaje autenticado.',
    null, gen_random_uuid(), null, v_user_hash,
    repeat('1',64), repeat('2',64));
  if v_status <> 'created' then raise exception 'authenticated message was not accepted'; end if;
  v_status := public.submit_contact_message_with_controls(
    'QA User', 'signed-in-2@example.test', 'Otro', 'Segundo mensaje autenticado.',
    null, gen_random_uuid(), null, v_user_hash,
    repeat('3',64), repeat('4',64));
  if v_status <> 'created' then raise exception 'authenticated second message was not accepted'; end if;
  v_status := public.submit_contact_message_with_controls(
    'QA User', 'signed-in-3@example.test', 'Otro', 'Tercer mensaje autenticado.',
    null, gen_random_uuid(), null, v_user_hash,
    repeat('5',64), repeat('6',64));
  if v_status <> 'created' then raise exception 'authenticated third message was not accepted'; end if;
  v_status := public.submit_contact_message_with_controls(
    'QA User', 'signed-in-4@example.test', 'Otro', 'Cuarto mensaje autenticado.',
    null, gen_random_uuid(), null, v_user_hash,
    repeat('7',64), repeat('8',64));
  if v_status <> 'rate_limited' then raise exception 'authenticated user rate limit did not activate'; end if;
end;
$$;

rollback;
select 'phase 3.29 contact controls contracts passed' as result;
