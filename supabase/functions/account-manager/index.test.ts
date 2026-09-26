import { handleRequest } from "./index.ts";

function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) throw new Error(`Expected ${expected}, got ${actual}`);
}

Deno.test("browser preflight requires no credentials or database access", async () => {
  const response = await handleRequest(new Request("https://example.test", {
    method: "OPTIONS",
    headers: { Origin: "https://app.nosus.foo" },
  }));
  equal(response.status, 204);
  equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  equal(response.headers.get("Access-Control-Allow-Methods"), "POST, OPTIONS");
});

for (const method of ["GET", "HEAD", "PUT", "DELETE"]) {
  Deno.test(`${method} cannot trigger account deletion, even with credentials`, async () => {
    const response = await handleRequest(new Request("https://example.test", {
      method,
      headers: { Authorization: "Bearer test-only" },
    }));
    equal(response.status, 405);
    equal(response.headers.get("Allow"), "POST, OPTIONS");
  });
}

Deno.test("unauthenticated POST is rejected with browser-readable CORS headers", async () => {
  const response = await handleRequest(new Request("https://example.test", { method: "POST" }));
  equal(response.status, 401);
  equal(response.headers.get("Access-Control-Allow-Origin"), "*");
});
