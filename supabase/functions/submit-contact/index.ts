import { createClient } from 'npm:@supabase/supabase-js@2';
import { validateContactInput } from '../_shared/contact_validation.ts';
import {
  contactControlHashes,
  contactResultHttpStatus,
  normalizeIdempotencyKey,
} from '../_shared/contact_submission.ts';
import { corsHeaders } from '../_shared/cors.ts';

function reply(body: Record<string, unknown>, status = 200, headers: HeadersInit = {}) {
  return Response.json(body, { status, headers });
}

async function limitedBody(request: Request): Promise<string | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const decoder = new TextDecoder();
  let text = '';
  let bytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    bytes += value.byteLength;
    if (bytes > 10000) {
      await reader.cancel();
      return null;
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

Deno.serve(async (request) => {
  const cors = corsHeaders(request);
  if (!cors) return reply({ error: 'ORIGIN_NOT_ALLOWED' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return reply({ error: 'METHOD_NOT_ALLOWED' }, 405, cors);

  const text = await limitedBody(request);
  if (text === null) return reply({ error: 'PAYLOAD_TOO_LARGE' }, 413, cors);
  let input: unknown;
  try {
    input = JSON.parse(text);
  } catch {
    return reply({ error: 'INVALID_BODY' }, 400, cors);
  }
  const contact = validateContactInput(input);
  if (contact === null) return reply({ error: 'INVALID_FIELDS' }, 400, cors);

  let idempotencyKey: string;
  try {
    idempotencyKey = normalizeIdempotencyKey(request.headers.get('Idempotency-Key'));
  } catch {
    return reply({ error: 'INVALID_IDEMPOTENCY_KEY' }, 400, cors);
  }

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return reply({ error: 'SERVICE_UNAVAILABLE' }, 503, cors);
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  let userId: string | null = null;
  const bearer = request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (bearer) {
    const { data } = await admin.auth.getUser(bearer);
    if (data.user && !data.user.is_anonymous) {
      const { data: profile } = await admin.from('profiles').select('id')
        .eq('id', data.user.id).maybeSingle();
      userId = profile?.id ?? null;
    }
  }

  const forwardedClientIp = request.headers.get('cf-connecting-ip')?.trim() ?? '';
  const hashes = await contactControlHashes({
    ip: forwardedClientIp.length > 0 && forwardedClientIp.length <= 128
      ? forwardedClientIp
      : null,
    userId,
    email: contact.email,
    subject: contact.subject,
    message: contact.message,
  });
  const { data: result, error } = await admin.rpc('submit_contact_message_with_controls', {
    p_name: contact.name,
    p_email: contact.email,
    p_subject: contact.subject,
    p_message: contact.message,
    p_user_id: userId,
    p_idempotency_key: idempotencyKey,
    p_ip_hash: hashes.ipHash,
    p_user_hash: hashes.userHash,
    p_email_hash: hashes.emailHash,
    p_fingerprint: hashes.fingerprint,
  });
  if (error) return reply({ error: 'SAVE_FAILED' }, 503, cors);
  const resultStatus = contactResultHttpStatus(result);
  if (resultStatus === 429) {
    const rateHeaders = new Headers(cors);
    rateHeaders.set('Retry-After', '3600');
    return reply({ error: 'RATE_LIMITED' }, resultStatus, rateHeaders);
  }
  if (resultStatus === 200) return reply({ ok: true, duplicate: true }, resultStatus, cors);
  if (resultStatus !== 201) return reply({ error: 'SAVE_FAILED' }, resultStatus, cors);
  return reply({ ok: true }, resultStatus, cors);
});
