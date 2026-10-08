const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function normalizeIdempotencyKey(value: string | null): string {
  const key = value?.trim() || crypto.randomUUID();
  if (!uuidPattern.test(key)) throw new Error('INVALID_IDEMPOTENCY_KEY');
  return key.toLowerCase();
}

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function contactControlHashes(input: {
  ip: string | null;
  userId: string | null;
  email: string;
  subject: string;
  message: string;
}) {
  const [ipHash, userHash, emailHash, fingerprint] = await Promise.all([
    input.ip ? sha256Hex(`ip:${input.ip.trim().toLowerCase()}`) : Promise.resolve(null),
    input.userId ? sha256Hex(`user:${input.userId.toLowerCase()}`) : Promise.resolve(null),
    sha256Hex(`email:${input.email.trim().toLowerCase()}`),
    sha256Hex(JSON.stringify([
      input.email.trim().toLowerCase(), input.subject.trim(),
      input.message.trim().replace(/\r\n/g, '\n'),
    ])),
  ]);
  return { ipHash, userHash, emailHash, fingerprint };
}

export function contactResultHttpStatus(value: unknown): number {
  if (value === 'created') return 201;
  if (value === 'duplicate') return 200;
  if (value === 'rate_limited') return 429;
  return 503;
}
