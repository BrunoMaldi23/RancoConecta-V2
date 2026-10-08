import { corsHeaders } from "./cors.ts";

Deno.test("CORS allows configured production and local development origins", () => {
  for (
    const origin of [
      "https://rancoconecta.cl",
      "https://www.rancoconecta.cl",
      "http://localhost:3000",
      "http://127.0.0.1:3000",
      "http://localhost:5000",
      "http://127.0.0.1:5000",
      "http://localhost:5173",
      "http://127.0.0.1:5173",
      "http://localhost:8080",
      "http://127.0.0.1:8080",
    ]
  ) {
    const headers = corsHeaders(
      new Request("https://edge.test", { headers: { Origin: origin } }),
    );
    if (
      !headers ||
      new Headers(headers).get("Access-Control-Allow-Origin") !== origin
    ) {
      throw new Error(`configured origin was not reflected: ${origin}`);
    }
    if (
      !new Headers(headers).get("Access-Control-Allow-Headers")?.includes(
        "idempotency-key",
      )
    ) {
      throw new Error("submission idempotency header is not allowed by CORS");
    }
  }
});

Deno.test("CORS rejects unrelated browser origins and permits originless API calls", () => {
  const denied = corsHeaders(
    new Request("https://edge.test", {
      headers: { Origin: "https://example.invalid" },
    }),
  );
  if (denied !== null) {
    throw new Error("unconfigured browser origin was allowed");
  }
  const originless = corsHeaders(new Request("https://edge.test"));
  if (
    !originless || new Headers(originless).has("Access-Control-Allow-Origin")
  ) {
    throw new Error("originless request should not receive a wildcard origin");
  }
});
