import { assertEquals } from "jsr:@std/assert@1";
import {
  makeSubmissionHashes,
  mapSubmissionResult,
  submissionErrorStatus,
  validatePublicSubmission,
} from "./public_submission.ts";

const valid = {
  kind: "service_request",
  business_id: "a7affb25-ad32-4836-be38-cb2af81343c7",
  category_id: "a7affb25-ad32-4836-be38-cb2af81343c7",
  subcategory_id: "a7affb25-ad32-4836-be38-cb2af81343c7",
  customer_name: "Cliente de prueba",
  customer_phone: "+56 9 1234 5678",
  consent_version: "privacy-2026-10-01",
  consent_accepted: true,
  description: "Necesito información del servicio",
  urgency: "normal",
};

Deno.test("accepts anonymous service request with Chilean phone format", () => {
  assertEquals(validatePublicSubmission(valid)?.kind, "service_request");
});
Deno.test("accepts table and lodging reservations without account fields", () => {
  const base = {
    business_id: valid.business_id,
    customer_name: valid.customer_name,
    customer_phone: valid.customer_phone,
    consent_version: valid.consent_version,
    consent_accepted: true,
    guests: 2,
    message: "Preferencia de horario",
  };
  assertEquals(
    validatePublicSubmission({
      ...base,
      kind: "table_reservation",
      reservation_date: "2026-10-10",
      reservation_time: "20:30",
    })?.kind,
    "table_reservation",
  );
  assertEquals(
    validatePublicSubmission({
      ...base,
      kind: "lodging_booking",
      check_in: "2026-10-10",
      check_out: "2026-10-12",
    })?.kind,
    "lodging_booking",
  );
});
Deno.test("rejects invalid phone, missing consent, invalid business, and oversized message", () => {
  for (
    const patch of [
      { customer_phone: "12" },
      { consent_version: null },
      { consent_accepted: false },
      { business_id: "nope" },
      { description: "x".repeat(4001) },
    ]
  ) assertEquals(validatePublicSubmission({ ...valid, ...patch }), null);
});
Deno.test("returns only controlled result statuses", async () => {
  const input = validatePublicSubmission(valid)!;
  const a = await makeSubmissionHashes(input, null, "test-hmac-secret");
  const b = await makeSubmissionHashes(input, null, "test-hmac-secret");
  assertEquals(a.fingerprint, b.fingerprint);
  assertEquals(mapSubmissionResult("created"), 201);
  assertEquals(mapSubmissionResult("duplicate"), 409);
  assertEquals(mapSubmissionResult("rate_limited"), 429);
  assertEquals(mapSubmissionResult("unexpected"), 503);
  assertEquals(submissionErrorStatus("P0002"), 404);
  assertEquals(submissionErrorStatus("22023"), 400);
  assertEquals(submissionErrorStatus("23P01"), 409);
  assertEquals(submissionErrorStatus("XX000"), 500);
});
