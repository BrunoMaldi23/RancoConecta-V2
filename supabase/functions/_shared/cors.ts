const allowedOrigins = new Set([
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
]);

const baseHeaders = {
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

export function corsHeaders(request: Request): HeadersInit | null {
  const origin = request.headers.get("Origin");
  if (origin && !allowedOrigins.has(origin)) return null;
  return origin
    ? { ...baseHeaders, "Access-Control-Allow-Origin": origin }
    : baseHeaders;
}
