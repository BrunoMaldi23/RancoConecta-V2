import { createClient } from 'npm:@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const reply = (body: Record<string, unknown>, status = 200, headers: HeadersInit = {}) =>
  Response.json(body, { status, headers });

async function limitedBody(request: Request): Promise<string | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const decoder = new TextDecoder();
  let result = '';
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 4096) {
      await reader.cancel();
      return null;
    }
    result += decoder.decode(value, { stream: true });
  }
  return result + decoder.decode();
}

Deno.serve(async (request) => {
  const cors = corsHeaders(request);
  if (!cors) return reply({ error: 'ORIGIN_NOT_ALLOWED' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return reply({ error: 'METHOD_NOT_ALLOWED' }, 405, cors);
  if (Number(request.headers.get('content-length') ?? 0) > 4096) {
    return reply({ error: 'PAYLOAD_TOO_LARGE' }, 413, cors);
  }
  const authorization = request.headers.get('Authorization');
  const token = authorization?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return reply({ error: 'UNAUTHORIZED' }, 401, cors);

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) {
    return reply({ error: 'SERVICE_UNAVAILABLE' }, 503, cors);
  }
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const caller = createClient(url, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authorization! } },
  });
  const { data: identity, error: identityError } = await caller.auth.getUser(token);
  if (identityError || !identity.user || identity.user.is_anonymous) {
    return reply({ error: 'UNAUTHORIZED' }, 401, cors);
  }
  const actorId = identity.user.id;
  const { data: authorized, error: authorizationError } = await caller
    .rpc('current_user_is_admin');
  if (authorizationError || authorized !== true) {
    return reply({ error: 'FORBIDDEN' }, 403, cors);
  }

  let input: Record<string, unknown>;
  try {
    const text = await limitedBody(request);
    if (text === null) return reply({ error: 'PAYLOAD_TOO_LARGE' }, 413, cors);
    const value = JSON.parse(text);
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error();
    input = value;
  } catch {
    return reply({ error: 'INVALID_BODY' }, 400, cors);
  }

  if (input.action === 'invite') {
    if (typeof input.name !== 'string' || typeof input.email !== 'string') {
      return reply({ error: 'INVALID_FIELDS' }, 400, cors);
    }
    const name = input.name.trim().replace(/\s+/g, ' ');
    const email = input.email.trim().toLowerCase();
    if (name.length < 3 || name.length > 120 || email.length > 254 ||
        !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return reply({ error: 'INVALID_FIELDS' }, 400, cors);
    }
    const { data: invited, error: inviteError } = await admin.auth.admin
      .inviteUserByEmail(email, { data: { full_name: name } });
    const userId = invited?.user?.id;
    if (inviteError || !userId) return reply({ error: 'INVITE_FAILED' }, 409, cors);

    const { error: profileSaveError } = await admin.from('profiles').upsert({
      id: userId, full_name: name, role: 'admin', account_status: 'active',
    }, { onConflict: 'id' });
    const { error: auditError } = profileSaveError ? { error: profileSaveError } :
      await admin.from('audit_logs').insert({
        actor_id: actorId, action: 'admin_user_created',
        entity_type: 'profile', entity_id: userId,
        new_data: { role: 'admin' },
      });
    if (profileSaveError || auditError) {
      await admin.auth.admin.deleteUser(userId);
      return reply({ error: 'CREATE_FAILED' }, 503, cors);
    }
    return reply({ ok: true, user_id: userId }, 201, cors);
  }

  if (input.action === 'delete') {
    if (typeof input.user_id !== 'string' ||
        !/^[0-9a-f]{8}-[0-9a-f-]{27,}$/i.test(input.user_id)) {
      return reply({ error: 'INVALID_USER' }, 400, cors);
    }
    const { data: summary, error: prepareError } = await caller
      .rpc('admin_mark_user_deleted', { p_user_id: input.user_id });
    if (prepareError) {
      const code = ['LAST_ADMIN', 'SELF_DELETE_NOT_ALLOWED',
        'PROTECTED_ADMIN', 'USER_NOT_FOUND'].find((item) =>
          prepareError.message.includes(item)) ?? 'DELETE_NOT_ALLOWED';
      return reply({ error: code },
        prepareError.code === '42501' ? 403 : 409, cors);
    }
    // Keep the Auth identity so historical rows and business ownership remain
    // intact. admin_mark_user_deleted blocks the profile and records the audit.
    return reply({ ok: true, related_tables: summary?.related_tables ?? [] }, 200, cors);
  }
  return reply({ error: 'UNKNOWN_ACTION' }, 400, cors);
});
