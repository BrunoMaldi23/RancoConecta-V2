import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  makeSubmissionHashes,
  mapSubmissionResult,
  submissionErrorStatus,
  validatePublicSubmission,
} from "../_shared/public_submission.ts";
import { normalizeIdempotencyKey } from "../_shared/contact_submission.ts";

function reply(
  body: Record<string, unknown>,
  status: number,
  headers: HeadersInit,
) {
  return Response.json(body, { status, headers });
}

async function readLimitedBody(request: Request): Promise<string | null> {
  const reader = request.body?.getReader();
  if (!reader) return null;
  const decoder = new TextDecoder();
  let text = "";
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 12000) {
      await reader.cancel();
      return null;
    }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

Deno.serve(async (request) => {
  const cors = corsHeaders(request);
  if (!cors) return reply({ error: "ORIGIN_NOT_ALLOWED" }, 403, {});
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: cors });
  }
  if (request.method !== "POST") {
    return reply({ error: "METHOD_NOT_ALLOWED" }, 405, cors);
  }
  const raw = await readLimitedBody(request);
  if (raw === null) return reply({ error: "PAYLOAD_TOO_LARGE" }, 413, cors);
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return reply({ error: "INVALID_BODY" }, 400, cors);
  }
  const input = validatePublicSubmission(body);
  if (!input) return reply({ error: "INVALID_FIELDS" }, 400, cors);
  let key: string;
  try {
    key = normalizeIdempotencyKey(request.headers.get("Idempotency-Key"));
  } catch {
    return reply({ error: "INVALID_IDEMPOTENCY_KEY" }, 400, cors);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) {
    return reply({ error: "SERVICE_UNAVAILABLE" }, 503, cors);
  }
  const db = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const ip = request.headers.get("cf-connecting-ip")?.trim() || null;
  const hashes = await makeSubmissionHashes(input, ip, serviceKey);
  let rpc: string;
  let params: Record<string, unknown>;
  const controls = {
    p_idempotency_key: key,
    p_fingerprint: hashes.fingerprint,
    p_phone_hash: hashes.phoneHash,
    p_ip_hash: hashes.ipHash,
  };
  if (input.kind === "service_request") {
    rpc = "submit_public_service_request";
    params = {
      p_business_id: input.business_id,
      p_category_id: input.category_id,
      p_subcategory_id: input.subcategory_id,
      p_location_id: input.location_id ?? null,
      p_description: input.description,
      p_address_text: input.address_text ?? null,
      p_urgency: input.urgency,
      p_desired_date: input.desired_date ?? null,
      p_customer_name: input.customer_name,
      p_customer_phone: input.customer_phone,
      p_consent_version: input.consent_version,
      p_idempotency_key: key,
      p_fingerprint: hashes.fingerprint,
      p_phone_hash: hashes.phoneHash,
      p_ip_hash: hashes.ipHash,
    };
  } else if (input.kind === "table_reservation") {
    rpc = "submit_public_table_reservation";
    params = {
      p_business_id: input.business_id,
      p_date: input.reservation_date,
      p_time: input.reservation_time,
      p_guests: input.guests,
      p_message: input.message ?? null,
      p_name: input.customer_name,
      p_phone: input.customer_phone,
      p_consent_version: input.consent_version,
      ...controls,
    };
  } else {
    rpc = "submit_public_lodging_booking";
    params = {
      p_business_id: input.business_id,
      p_check_in: input.check_in,
      p_check_out: input.check_out,
      p_guests: input.guests,
      p_message: input.message ?? null,
      p_name: input.customer_name,
      p_phone: input.customer_phone,
      p_consent_version: input.consent_version,
      ...controls,
    };
  }
  const { data, error } = await db.rpc(rpc, params);
  if (error) {
    const status = submissionErrorStatus(error.code);
    const code = status === 404
      ? "NOT_FOUND"
      : status === 400
      ? "INVALID_FIELDS"
      : status === 409
      ? "UNAVAILABLE"
      : "SAVE_FAILED";
    return reply({ error: code }, status, cors);
  }
  const status = mapSubmissionResult(data?.status);
  if (status === 429) {
    const headers = new Headers(cors);
    headers.set("Retry-After", "3600");
    return reply({ error: "RATE_LIMITED" }, status, headers);
  }
  if (status === 409) return reply({ error: "DUPLICATE" }, status, cors);
  if (status !== 201) return reply({ error: "SAVE_FAILED" }, status, cors);
  return reply({ ok: true }, 201, cors);
});
