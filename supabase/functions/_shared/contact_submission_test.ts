import {
  contactControlHashes,
  contactResultHttpStatus,
  normalizeIdempotencyKey,
} from './contact_submission.ts';

Deno.test('creates or validates a stable UUID idempotency key', () => {
  const generated = normalizeIdempotencyKey(null);
  if (!/^[0-9a-f-]{36}$/.test(generated)) throw new Error('generated key is invalid');
  const supplied = '550e8400-e29b-41d4-a716-446655440000';
  if (normalizeIdempotencyKey(supplied.toUpperCase()) !== supplied) {
    throw new Error('provided idempotency key was not normalized');
  }
  try {
    normalizeIdempotencyKey('not-a-uuid');
    throw new Error('invalid key was accepted');
  } catch (error) {
    if (!(error instanceof Error) || error.message !== 'INVALID_IDEMPOTENCY_KEY') throw error;
  }
});

Deno.test('hashes identity and duplicate fields without storing raw values', async () => {
  const first = await contactControlHashes({
    ip: '192.0.2.10', userId: null, email: 'USER@example.com',
    subject: 'Otro', message: 'Necesito ayuda con mi solicitud.',
  });
  const repeated = await contactControlHashes({
    ip: '192.0.2.10', userId: null, email: 'user@example.com',
    subject: 'Otro', message: 'Necesito ayuda con mi solicitud.',
  });
  if (first.fingerprint !== repeated.fingerprint || first.emailHash !== repeated.emailHash) {
    throw new Error('normalized duplicate input produced unstable hashes');
  }
  if (first.ipHash?.includes('192.0.2.10') || first.emailHash.includes('user@example.com')) {
    throw new Error('a raw identity was returned instead of a hash');
  }
  if (![first.ipHash, first.emailHash, first.fingerprint].every((item) =>
      typeof item === 'string' && /^[0-9a-f]{64}$/.test(item))) {
    throw new Error('SHA-256 hash has the wrong shape');
  }
  const withoutNetworkSignal = await contactControlHashes({
    ip: null, userId: null, email: 'other@example.com',
    subject: 'Otro', message: 'Mensaje válido para contacto sin IP.',
  });
  if (withoutNetworkSignal.ipHash !== null || !/^[0-9a-f]{64}$/.test(withoutNetworkSignal.emailHash)) {
    throw new Error('email hash must support rate limiting when client IP is unavailable');
  }
  const signedIn = await contactControlHashes({
    ip: null, userId: '00000000-0000-4000-8000-000000000123',
    email: 'user@example.com', subject: 'Consulta', message: 'Mensaje de prueba.',
  });
  if (!/^[0-9a-f]{64}$/.test(signedIn.userHash ?? '') ||
      signedIn.userHash?.includes('00000000-0000')) {
    throw new Error('authenticated user signal must be hashed');
  }
});

Deno.test('maps durable contact outcomes to safe HTTP statuses', () => {
  if (contactResultHttpStatus('created') !== 201 ||
      contactResultHttpStatus('duplicate') !== 200 ||
      contactResultHttpStatus('rate_limited') !== 429 ||
      contactResultHttpStatus('unexpected') !== 503) {
    throw new Error('contact status mapping is unsafe');
  }
});
