import { createClient } from 'npm:@supabase/supabase-js@2';

type BusinessRecord = {
  id: string;
  owner_id: string;
  name: string;
  email?: string | null;
  phone?: string | null;
  whatsapp?: string | null;
  publication_status: string;
};

// Receives an internal Database Webhook on businesses UPDATE.
// All contact details stay inside this Supabase project.
Deno.serve(async (request) => {
  const secret = Deno.env.get('ADMIN_NOTIFICATION_WEBHOOK_SECRET');
  if (!secret || request.headers.get('x-webhook-secret') !== secret) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const payload = await request.json().catch(() => null) as {
    type?: string;
    table?: string;
    record?: BusinessRecord;
    old_record?: BusinessRecord;
  } | null;
  const business = payload?.record;
  if (payload?.type !== 'UPDATE' || payload.table !== 'businesses' ||
      !business?.id || business.publication_status !== 'pending_review' ||
      payload.old_record?.publication_status === 'pending_review') {
    return Response.json({ skipped: true });
  }

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    return Response.json({ error: 'Supabase server secrets are missing' }, { status: 503 });
  }
  const admin = createClient(url, serviceKey);
  const [
    { data: owner, error: ownerError },
    { data: admins, error: adminsError },
    { data: authUser, error: authError },
  ] = await Promise.all([
    admin.from('profiles').select('full_name,phone').eq('id', business.owner_id).single(),
    admin.from('profiles').select('id').in('role', ['admin', 'super_admin']).eq('account_status', 'active'),
    admin.auth.admin.getUserById(business.owner_id),
  ]);
  if (ownerError || adminsError || authError) {
    return Response.json({ error: 'Could not load internal recipients' }, { status: 502 });
  }
  const body = [
    `Nombre: ${owner?.full_name ?? 'No informado'}`,
    `Negocio: ${business.name}`,
    `Correo: ${business.email || authUser?.user?.email || 'No informado'}`,
    `Teléfono: ${business.whatsapp || business.phone || owner?.phone || 'No informado'}`,
  ].join('\n');
  const deepLink = `/admin/businesses/${encodeURIComponent(business.id)}`;
  for (const recipient of admins ?? []) {
    const { error } = await admin.from('notifications').insert({
      user_id: recipient.id,
      type: 'provider_pending_review',
      title: 'Nuevo proveedor pendiente revisión',
      body,
      entity_type: 'business',
      entity_id: business.id,
      deep_link: deepLink,
    });
    if (error && error.code !== '23505') {
      return Response.json({ error: 'Could not save admin notification' }, { status: 502 });
    }
  }
  return Response.json({ notified: admins?.length ?? 0 });
});
