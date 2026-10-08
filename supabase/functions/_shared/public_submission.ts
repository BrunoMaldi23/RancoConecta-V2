export type PublicSubmission = Record<string, string | number | null> & {
  kind: string;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const phoneDigits = (value: string) => value.replace(/\D/g, "");
const validDate = (value: string) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().startsWith(value);
};

export function validatePublicSubmission(
  value: unknown,
): PublicSubmission | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const v = value as Record<string, unknown>;
  const kind = v.kind;
  if (
    !["service_request", "table_reservation", "lodging_booking"].includes(
      String(kind),
    )
  ) return null;
  if (
    Object.keys(v).some((k) =>
      ![
        "kind",
        "business_id",
        "category_id",
        "subcategory_id",
        "location_id",
        "description",
        "address_text",
        "urgency",
        "desired_date",
        "reservation_date",
        "reservation_time",
        "guests",
        "check_in",
        "check_out",
        "message",
        "customer_name",
        "customer_phone",
        "consent_version",
        "consent_accepted",
      ].includes(k)
    )
  ) return null;
  const string = (key: string, max: number) =>
    typeof v[key] === "string" && (v[key] as string).trim().length <= max;
  if (
    !string("business_id", 36) || !uuidPattern.test(v.business_id as string) ||
    !string("customer_name", 100) ||
    (v.customer_name as string).trim().length < 2 ||
    !string("customer_phone", 32)
  ) return null;
  const phone = phoneDigits(v.customer_phone as string);
  if (
    !((phone.length === 9 && /^[2-9]/.test(phone)) ||
      (phone.length === 11 && /^56[2-9]/.test(phone)))
  ) return null;
  if (v.consent_version !== "privacy-2026-10-01") return null;
  if (v.consent_accepted !== true) return null;
  if (kind === "service_request") {
    if (
      typeof v.category_id !== "string" || !uuidPattern.test(v.category_id) ||
      typeof v.subcategory_id !== "string" ||
      !uuidPattern.test(v.subcategory_id) ||
      !string("description", 4000) ||
      (v.description as string).trim().length < 12 ||
      (v.address_text != null && !string("address_text", 500)) ||
      (v.desired_date != null &&
        (typeof v.desired_date !== "string" || !validDate(v.desired_date))) ||
      !["low", "normal", "high", "urgent"].includes(String(v.urgency))
    ) return null;
  } else if (kind === "table_reservation") {
    const time = typeof v.reservation_time === "string"
      ? v.reservation_time
      : "";
    const [hour, minute] = time.split(":").map(Number);
    if (
      !string("reservation_date", 10) ||
      !validDate(v.reservation_date as string) ||
      !string("reservation_time", 8) || !/^\d{2}:\d{2}(:\d{2})?$/.test(time) ||
      hour > 23 || minute > 59 ||
      !Number.isInteger(v.guests) || (v.guests as number) < 1 ||
      (v.guests as number) > 20 ||
      (v.message != null && !string("message", 1000))
    ) return null;
  } else if (
    !string("check_in", 10) || !validDate(v.check_in as string) ||
    !string("check_out", 10) || !validDate(v.check_out as string) ||
    (v.check_in as string) >= (v.check_out as string) ||
    !Number.isInteger(v.guests) || (v.guests as number) < 1 ||
    (v.guests as number) > 30 ||
    (v.message != null && !string("message", 2000))
  ) return null;
  if (
    v.location_id != null &&
    (typeof v.location_id !== "string" || !uuidPattern.test(v.location_id))
  ) return null;
  return v as PublicSubmission;
}

export async function makeSubmissionHashes(
  input: PublicSubmission,
  ip: string | null,
  hmacSecret: string,
) {
  const phone = phoneDigits(String(input.customer_phone));
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(hmacSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const hmac = async (value: string) => {
    const signature = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(value),
    );
    return [...new Uint8Array(signature)].map((byte) =>
      byte.toString(16).padStart(2, "0")
    ).join("");
  };
  const [phoneHash, ipHash, fingerprint] = await Promise.all([
    hmac(`phone:${phone}`),
    ip ? hmac(`ip:${ip.trim().toLowerCase()}`) : Promise.resolve(null),
    hmac(JSON.stringify(input)),
  ]);
  return { phoneHash, ipHash, fingerprint };
}

export function mapSubmissionResult(value: unknown): number {
  if (value === "created") return 201;
  if (value === "duplicate") return 409;
  if (value === "rate_limited") return 429;
  return 503;
}

export function submissionErrorStatus(code: string | undefined): number {
  if (code === "P0002") return 404;
  if (code === "22023") return 400;
  if (code === "23P01") return 409;
  return 500;
}
