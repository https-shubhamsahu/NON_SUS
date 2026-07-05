// Deno unit tests for the pact-matcher Edge Function
// Run with: deno test --allow-env supabase/functions/pact-matcher/test.ts

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequest } from "./index.ts";

Deno.env.set("SUPABASE_URL", "https://mock.supabase.co");
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "mock-service-role-key");

Deno.test("pact-matcher - processes webhook inputs, evaluates and commits matches", async () => {
  const originalFetch = globalThis.fetch;

  // Intercept and mock all HTTP requests (Supabase REST API and edge function invocations)
  globalThis.fetch = async (input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();

    // 1. Mock Supabase Rest calls
    if (url.includes("mock.supabase.co/rest/v1")) {
      // Mock arena_members query for sealer A (user_id = eq.user-a)
      if (url.includes("arena_members") && url.includes("user_id=eq.user-a")) {
        return new Response(JSON.stringify([{ arena_public_id: 1 }]), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      // Mock arena_members query for candidate B (user_id = eq.user-b)
      if (url.includes("arena_members") && url.includes("user_id=eq.user-b")) {
        return new Response(JSON.stringify([{ arena_public_id: 2 }]), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      // Mock seals query to find candidate counter-seals
      if (url.includes("seals") && url.includes("status=eq.pending") && url.includes("sealer_id=neq.user-a")) {
        return new Response(
          JSON.stringify([{ sealer_id: "user-b", sealed_choice: "encrypted-choice-b" }]),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          },
        );
      }
      // Mock matches insert
      if (url.includes("matches")) {
        return new Response(JSON.stringify([{ id: "match-uuid" }]), {
          status: 201,
          headers: { "content-type": "application/json" },
        });
      }
      // Mock seals status update
      if (url.includes("seals") && init?.method === "PATCH") {
        return new Response(JSON.stringify([{ status: "matched" }]), {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      // Mock fhe_events insert
      if (url.includes("fhe_events")) {
        return new Response(JSON.stringify([{ id: "event-uuid" }]), {
          status: 201,
          headers: { "content-type": "application/json" },
        });
      }
    }

    // 2. Mock Edge Function (fhe-proxy) invocations
    if (url.includes("mock.supabase.co/functions/v1/fhe-proxy")) {
      const reqBody = JSON.parse(init?.body as string);
      if (reqBody.action === "pact_evaluate") {
        return new Response(
          JSON.stringify({
            result: { encrypted_match: "encrypted-bool-match" },
          }),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          },
        );
      }
      if (reqBody.action === "pact_decrypt") {
        return new Response(
          JSON.stringify({
            result: { mutual: true },
          }),
          {
            status: 200,
            headers: { "content-type": "application/json" },
          },
        );
      }
    }

    return new Response(JSON.stringify({}), { status: 200 });
  };

  try {
    // Construct mock request representing a database webhook payload
    const req = new Request("https://mock.supabase.co/functions/v1/pact-matcher", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer mock-service-role-key",
      },
      body: JSON.stringify({
        type: "INSERT",
        table: "seals",
        schema: "public",
        record: {
          id: "seal-uuid-a",
          arena_id: "arena-uuid",
          sealer_id: "user-a",
          sealed_choice: "encrypted-choice-a",
          intent_kind: "crush",
          status: "pending",
        },
      }),
    });

    const res = await handleRequest(req);
    assertEquals(res.status, 200);

    const data = await res.json();
    assertEquals(data.matched, true);
    assertEquals(data.match.user_a, "user-a");
    assertEquals(data.match.user_b, "user-b");
    assertEquals(data.match.intent_kind, "crush");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
