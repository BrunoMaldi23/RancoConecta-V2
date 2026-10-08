// Local-only HTTP integration checks. Never prints local keys or passwords.
import assert from 'node:assert/strict';
import { execFileSync, execSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';

const status = JSON.parse(execSync('npx -y supabase status -o json', {
  encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'],
}));
const base = status.API_URL;
const anon = status.ANON_KEY;
const service = status.SERVICE_ROLE_KEY;
assert.match(base, /^http:\/\/(127\.0\.0\.1|localhost):54321$/);

async function call(method, path, { key = anon, token = key, body, headers = {} } = {}) {
  const response = await fetch(base + path, {
    method,
    headers: {
      ...(key ? { apikey: key } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
      ...headers,
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const raw = await response.text();
  let data;
  try { data = JSON.parse(raw); } catch { data = raw; }
  return { status: response.status, data, headers: response.headers };
}

function sql(query) {
  return execFileSync('docker', [
    'exec', 'supabase_db_ranco_conecta_2', 'psql', '-U', 'postgres', '-d',
    'postgres', '-X', '-v', 'ON_ERROR_STOP=1', '-t', '-A', '-c', query,
  ], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

function uuid(value) {
  assert.match(value, /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
  return value;
}

function expectStatus(result, code, label) {
  assert.equal(result.status, code, `${label}: HTTP ${result.status} ${JSON.stringify(result.data)}`);
  return result.data;
}

const rpc = (name, token, body) => call('POST', `/rest/v1/rpc/${name}`, { token, body });

const suffix = randomUUID().slice(0, 8);
const adminEmail = `qa3252-admin-${suffix}@example.test`;
const userEmail = `qa3252-user-${suffix}@example.test`;
const invitedEmail = `qa3252-invited-${suffix}@example.test`;
const password = `${randomUUID()}A1!`;

async function createUser(email, name) {
  const data = expectStatus(await call('POST', '/auth/v1/admin/users', {
    key: service,
    body: { email, password, email_confirm: true, user_metadata: { full_name: name } },
  }), 200, 'create local Auth user');
  return uuid(data.id);
}

async function signIn(email) {
  const data = expectStatus(await call('POST', '/auth/v1/token?grant_type=password', {
    body: { email, password },
  }), 200, 'local sign-in');
  return data.access_token;
}

const adminId = await createUser(adminEmail, 'QA Admin');
const userId = await createUser(userEmail, 'QA User');
sql(`update public.profiles set role = 'super_admin', account_status = 'active' where id = '${adminId}'`);
sql(`update public.profiles set account_status = 'active' where id = '${userId}'`);
for (const name of ['admin_business_review_stats', 'admin_analytics_summary']) {
  const denied = await rpc(name, anon, {});
  assert.ok([401, 403].includes(denied.status),
    `${name} must deny anon after EXECUTE revocation: ${denied.status}`);
}
sql(`insert into public.super_admin_sessions(user_id,purpose,expires_at) values('${adminId}','Local integration QA admin session',now()+interval '50 minutes')`);
const adminJwt = await signIn(adminEmail);
const userJwt = await signIn(userEmail);
console.log('Auth local: admin y usuario creados');

const validContact = {
  name: `Ana Prueba ${suffix}`, email: 'ana@example.test',
  subject: 'Consulta general', message: 'Consulta local de integraciÃ³n.',
};
expectStatus(await call('GET', '/functions/v1/submit-contact'), 405, 'contact method');
const options = await call('OPTIONS', '/functions/v1/submit-contact', {
  key: null, token: null, headers: { Origin: 'https://www.rancoconecta.cl' },
});
assert.equal(options.status, 200);
const deniedOrigin = await call('POST', '/functions/v1/submit-contact', {
  key: anon, token: null, body: validContact,
  headers: { Origin: 'https://example.invalid' },
});
assert.equal(deniedOrigin.status, 403);
const adminOptions = await call('OPTIONS', '/functions/v1/admin-user', {
  key: null, token: null, headers: { Origin: 'https://rancoconecta.cl' },
});
assert.equal(adminOptions.status, 200);
for (const [label, body, code] of [
  ['missing name', { ...validContact, name: '' }, 400],
  ['bad email', { ...validContact, email: 'invalid' }, 400],
  ['bad subject', { ...validContact, subject: 'Inventado' }, 400],
  ['missing message', { ...validContact, message: '' }, 400],
  ['oversize message', { ...validContact, message: 'x'.repeat(4001) }, 400],
  ['oversize body', { ...validContact, message: 'x'.repeat(11000) }, 413],
  ['unexpected field', { ...validContact, is_admin: true }, 400],
]) {
  expectStatus(await call('POST', '/functions/v1/submit-contact', { body }), code, `contact ${label}`);
}
expectStatus(await call('POST', '/functions/v1/submit-contact', {
  key: anon, token: null, body: validContact,
}), 201, 'anonymous contact');
expectStatus(await call('POST', '/functions/v1/submit-contact', {
  token: userJwt, body: { ...validContact, name: `Usuario Local ${suffix}` },
}), 201, 'signed-in contact');
const contacts = expectStatus(await call('GET',
  '/rest/v1/contact_messages?select=id,name,user_id,status,created_at&order=created_at.desc&limit=1000',
  { key: service }), 200, 'service contact read');
const anonymousContact = contacts.find((item) => item.name === validContact.name);
const signedContact = contacts.find((item) => item.name === `Usuario Local ${suffix}`);
assert.ok(anonymousContact?.id && signedContact?.id);
assert.equal(anonymousContact.user_id, null);
assert.equal(signedContact.user_id, userId);
assert.equal(anonymousContact.status, 'new');
assert.ok(Date.parse(anonymousContact.created_at));
assert.equal(contacts.filter((item) => item.name === validContact.name).length, 1);
console.log('Contacto Edge: vÃ¡lido, invÃ¡lido, anÃ³nimo y autenticado OK');

for (const [label, token] of [['anon', anon], ['user', userJwt]]) {
  const list = await call('GET', '/rest/v1/contact_messages?select=id', { token });
  assert.ok(list.status === 401 || list.status === 403 ||
    (list.status === 200 && list.data.length === 0), `${label} read contacts`);
  for (const [method, path, body] of [
    ['POST', '/rest/v1/contact_messages', validContact],
    ['PATCH', `/rest/v1/contact_messages?id=eq.${anonymousContact.id}`, { status: 'resolved' }],
    ['DELETE', `/rest/v1/contact_messages?id=eq.${anonymousContact.id}`, undefined],
  ]) {
    const result = await call(method, path, { token, body });
    assert.ok(result.status === 401 || result.status === 403, `${label} ${method} contact: ${result.status}`);
  }
}
const adminContacts = expectStatus(await call('GET',
  `/rest/v1/contact_messages?select=id&id=eq.${anonymousContact.id}`,
  { token: adminJwt }), 200, 'admin contact read');
assert.equal(adminContacts.length, 1);
console.log('Contacto RLS: anon/usuario sin escritura ni lectura administrativa OK');

expectStatus(await call('POST', '/functions/v1/admin-user', {
  key: anon, token: null, body: { action: 'invite', name: 'Nuevo Admin', email: invitedEmail },
}), 401, 'admin no JWT');
expectStatus(await call('POST', '/functions/v1/admin-user', {
  token: userJwt, body: { action: 'invite', name: 'Nuevo Admin', email: invitedEmail },
}), 403, 'admin normal user denied');
expectStatus(await call('GET', '/functions/v1/admin-user', { token: adminJwt }), 405, 'admin method');
expectStatus(await call('POST', '/functions/v1/admin-user', {
  token: adminJwt, body: { action: 'invite', name: '', email: 'invalid' },
}), 400, 'admin invalid payload');
const invitation = expectStatus(await call('POST', '/functions/v1/admin-user', {
  token: adminJwt, body: { action: 'invite', name: 'Invitada Local', email: invitedEmail },
}), 201, 'admin invitation');
const invitedId = uuid(invitation.user_id);
const invitedProfile = expectStatus(await call('GET',
  `/rest/v1/profiles?select=id,role,account_status&id=eq.${invitedId}`,
  { key: service }), 200, 'invited profile');
assert.equal(invitedProfile[0]?.role, 'admin');
assert.equal(invitedProfile[0]?.account_status, 'active');
const invitedAuth = expectStatus(await call('GET', `/auth/v1/admin/users/${invitedId}`,
  { key: service }), 200, 'invited Auth user');
assert.equal(invitedAuth.email, invitedEmail);
console.log('Admin Edge: permisos e invitaciÃ³n Auth/perfil OK');

expectStatus(await call('POST', '/functions/v1/admin-user', {
  token: userJwt, body: { action: 'delete', user_id: adminId },
}), 403, 'normal user deletion denied');
expectStatus(await rpc('admin_change_user_role', adminJwt,
  { p_user_id: invitedId, p_role: 'customer' }), 204, 'demote second admin');
const lastAdminDemotion = await rpc('admin_change_user_role', adminJwt,
  { p_user_id: adminId, p_role: 'customer' });
assert.equal(lastAdminDemotion.status, 403);
assert.match(JSON.stringify(lastAdminDemotion.data), /ROLE_CHANGE_NOT_ALLOWED/);
console.log('Ãšltimo administrador: protegido del lado servidor');

assert.equal((await rpc('admin_change_user_role', userJwt,
  { p_user_id: userId, p_role: 'provider' })).status, 403);
expectStatus(await rpc('admin_change_user_role', adminJwt,
  { p_user_id: userId, p_role: 'provider' }), 204, 'role change');
expectStatus(await rpc('admin_set_account_suspension', adminJwt,
  { p_user_id: userId, p_suspended: true }), 204, 'suspend');
let profile = expectStatus(await call('GET',
  `/rest/v1/profiles?select=role,account_status&id=eq.${userId}`,
  { key: service }), 200, 'suspended profile');
assert.equal(profile[0].account_status, 'suspended');
expectStatus(await rpc('admin_set_account_suspension', adminJwt,
  { p_user_id: userId, p_suspended: false }), 204, 'reactivate');
assert.equal((await rpc('admin_set_account_suspension', adminJwt,
  { p_user_id: adminId, p_suspended: true })).status, 400);
assert.equal((await call('POST', '/functions/v1/admin-user', {
  token: adminJwt, body: { action: 'delete', user_id: adminId },
})).status, 403);
console.log('Admin RPC: rol, suspensiÃ³n, reactivaciÃ³n y auto protecciÃ³n OK');

expectStatus(await rpc('admin_update_contact_channels', adminJwt,
  { p_email: 'qa-support@example.test', p_whatsapp: '+56912345678' }), 204,
  'contact settings');
const channels = expectStatus(await rpc('public_contact_channels', anon, {}),
  200, 'public contact settings');
assert.equal(channels.email, 'qa-support@example.test');
assert.equal(channels.whatsapp, '56912345678');
assert.equal((await rpc('admin_update_contact_channels', userJwt,
  { p_email: 'evil@example.test', p_whatsapp: '' })).status, 403);
expectStatus(await rpc('admin_update_notification_settings', adminJwt,
  { p_new_business: true, p_business_changes: true, p_contact_message: false }),
  204, 'notification settings off');
const priorNoticeCount = Number(sql(`select count(*) from public.notifications where type='contact_message' and user_id='${adminId}'`));
expectStatus(await call('POST', '/functions/v1/submit-contact', {
  body: { ...validContact, name: 'Sin aviso' },
}), 201, 'contact with notices disabled');
const laterNoticeCount = Number(sql(`select count(*) from public.notifications where type='contact_message' and user_id='${adminId}'`));
assert.equal(laterNoticeCount, priorNoticeCount);
expectStatus(await rpc('admin_update_notification_settings', adminJwt,
  { p_new_business: true, p_business_changes: true, p_contact_message: true }),
  204, 'notification settings on');
console.log('ConfiguraciÃ³n y preferencia de aviso: persistencia y permisos OK');

expectStatus(await rpc('admin_update_whatsapp_settings', adminJwt, {
  p_number: '+56912345678', p_enabled: true,
  p_new_business: true, p_changes: false, p_reports: true,
}), 204, 'WhatsApp settings');
const whatsappRows = expectStatus(await call('GET',
  '/rest/v1/system_settings?select=key,value&key=in.(admin_whatsapp_number,whatsapp_notifications_enabled,whatsapp_notify_business_changes)',
  { token: adminJwt }), 200, 'WhatsApp settings persisted');
const whatsapp = Object.fromEntries(whatsappRows.map((item) => [item.key, item.value]));
assert.equal(whatsapp.admin_whatsapp_number, '56912345678');
assert.equal(whatsapp.whatsapp_notifications_enabled, true);
assert.equal(whatsapp.whatsapp_notify_business_changes, false);
assert.equal((await rpc('admin_update_whatsapp_settings', userJwt, {
  p_number: '56912345678', p_enabled: true,
  p_new_business: true, p_changes: true, p_reports: true,
})).status, 403);
console.log('WhatsApp: nÃºmero, flags y permisos persistidos; envÃ­o manual intacto');

const notices = expectStatus(await rpc('notification_list', adminJwt, {}), 200,
  'notification list');
const contactNotice = notices.find((item) => item.type === 'contact_message');
assert.ok(contactNotice?.id);
const unreadBefore = expectStatus(await rpc('unread_notification_count', adminJwt, {}),
  200, 'unread count');
assert.ok(unreadBefore > 0);
expectStatus(await rpc('mark_notification_read', adminJwt,
  { p_notification_id: contactNotice.id }), 204, 'mark one read');
expectStatus(await rpc('mark_all_notifications_read', adminJwt, {}), 204,
  'mark all read');
const unreadAfter = expectStatus(await rpc('unread_notification_count', adminJwt, {}),
  200, 'unread count persisted');
assert.equal(unreadAfter, 0);
console.log('Notificaciones: listado, lectura individual/total y contador persistidos OK');

const businessId = randomUUID();
const categoryAndSubcategory = sql('select c.id::text || \'|\' || s.id::text from public.categories c join public.subcategories s on s.category_id=c.id limit 1');
const [categoryId, subcategoryId] = categoryAndSubcategory.split('|').map(uuid);
const requestId = randomUUID();
const lodgingBusinessId = randomUUID();
sql(`insert into public.businesses(id, owner_id, business_type, name, slug)
  values('${businessId}','${userId}','service','QA Related','qa-related-${suffix}')`);
sql(`insert into public.businesses(id, owner_id, business_type, name, slug)
  values('${lodgingBusinessId}','${userId}','lodging','QA Lodging','qa-lodging-${suffix}')`);
sql(`insert into public.service_requests(id, customer_id, business_id, category_id, subcategory_id, description)
  values('${requestId}','${userId}','${businessId}','${categoryId}','${subcategoryId}','QA request retained')`);
const bookingId = randomUUID();
sql(`insert into public.lodging_bookings(id, business_id, guest_user_id, guest_name,
  check_in, check_out, guests, nights, total_amount)
  values('${bookingId}','${lodgingBusinessId}','${userId}','QA Guest',
    '2026-11-01','2026-11-03',2,2,20000)`);
sql(`insert into public.notifications(user_id,type,title,body)
  values('${userId}','system_notice','QA retained','QA retained')`);
sql(`update public.businesses set publication_status='pending_review' where id='${businessId}'`);
let businessNotices = Number(sql(`select count(*) from public.notifications where user_id='${adminId}' and entity_id='${businessId}' and type='provider_pending_review'`));
assert.equal(businessNotices, 1);
sql(`update public.businesses set publication_status='pending_review' where id='${businessId}'`);
assert.equal(Number(sql(`select count(*) from public.notifications where user_id='${adminId}' and entity_id='${businessId}' and type='provider_pending_review'`)), businessNotices);
sql(`update public.businesses set publication_status='changes_requested' where id='${businessId}'`);
sql(`update public.businesses set publication_status='pending_review' where id='${businessId}'`);
businessNotices = Number(sql(`select count(*) from public.notifications where user_id='${adminId}' and entity_id='${businessId}' and type='provider_changes_review'`));
assert.equal(businessNotices, 1);
console.log('Negocio pendiente/modificaciÃ³n: destinatario y deduplicaciÃ³n OK');
const deletion = expectStatus(await call('POST', '/functions/v1/admin-user', {
  token: adminJwt, body: { action: 'delete', user_id: userId },
}), 200, 'logical deletion');
assert.ok(deletion.related_tables.includes('businesses'));
profile = expectStatus(await call('GET',
  `/rest/v1/profiles?select=role,account_status,full_name&id=eq.${userId}`,
  { key: service }), 200, 'deleted profile');
assert.equal(profile[0].account_status, 'deleted');
assert.equal(profile[0].full_name, null);
assert.equal(sql(`select count(*) from public.businesses where id='${businessId}'`), '1');
assert.equal(sql(`select count(*) from public.businesses where id='${lodgingBusinessId}'`), '1');
assert.equal(sql(`select count(*) from public.service_requests where id='${requestId}'`), '1');
assert.equal(sql(`select count(*) from public.lodging_bookings where id='${bookingId}'`), '1');
assert.equal(sql(`select deleted_at is null from auth.users where id='${userId}'`), 't');
assert.ok(Number(sql(`select count(*) from public.notifications where user_id='${userId}'`)) >= 1);
const activeSearch = expectStatus(await rpc('admin_search_users', adminJwt, {
  p_page: 1, p_page_size: 10, p_search: userEmail, p_role: null, p_status: 'active',
}), 200, 'active admin search');
assert.equal(activeSearch.total_count, 0);
const audit = expectStatus(await call('GET',
  '/rest/v1/audit_logs?select=actor_id,action,entity_id,created_at&order=created_at.desc&limit=100',
  { key: service }), 200, 'audit history');
for (const action of ['admin_user_created', 'user_role_changed', 'user_suspended',
  'user_reactivated', 'user_deleted', 'admin_settings_updated']) {
  assert.ok(audit.some((row) => row.action === action &&
    row.actor_id === adminId && Date.parse(row.created_at)), `audit ${action}`);
}
console.log('Eliminación lógica: Auth preservado, negocio, solicitud, reserva, notificaciÃ³n y auditorÃ­a OK');
console.log('HTTP integration: PASS');

