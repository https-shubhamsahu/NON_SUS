// Supabase Edge Function: fhe-proxy
//
// The ONLY bridge between the Flutter app and the Rust FHE microservice.
// Flutter -> (JWT) -> fhe-proxy -> (service token) -> fhe-compute (TFHE-rs).
//
// Responsibilities:
//   1. Authenticate the caller's Supabase JWT and derive their tenant (user_id).
//   2. Enforce replay protection (nonce + timestamp window) using fhe_nonces.
//   3. Forward the request to the Rust service; never expose the service URL,
//      service token, or any key material to the client.
//   4. Mirror job state into fhe_compute_jobs and append fhe_events (service
//      role) so the client gets realtime updates and an audit trail.
//
// Secrets (set via `supabase secrets set`):
//   FHE_COMPUTE_URL     e.g. https://fhe.internal.example.com  (Rust service)
//   FHE_SERVICE_TOKEN   shared bearer token the Rust service trusts
//   SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY  (auto-injected)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const REPLAY_WINDOW_MS = 5 * 60 * 1000; // 5 minutes
type AdminClient = any;

// Client action -> Rust service (method, path). Keeps the app decoupled from
// the microservice's internal routing.
const ROUTES: Record<string, { method: string; path: string }> = {
  generate_keys: { method: "POST", path: "/keys/generate" },
  rotate_keys: { method: "POST", path: "/keys/rotate" },
  revoke_keys: { method: "POST", path: "/keys/revoke" },
  encrypt: { method: "POST", path: "/encrypt" },
  decrypt: { method: "POST", path: "/decrypt" },
  compute: { method: "POST", path: "/compute" },
  submit_job: { method: "POST", path: "/jobs" },
  compare: { method: "POST", path: "/compare" },
  mux: { method: "POST", path: "/mux" },
  memory_search: { method: "POST", path: "/memory/search" },
  policy_evaluate: { method: "POST", path: "/policy/evaluate" },
  similarity: { method: "POST", path: "/similarity" },
  pact_evaluate: { method: "POST", path: "/pact/evaluate" },
  pact_seal: { method: "POST", path: "/pact/seal" },
  pact_decrypt: { method: "POST", path: "/pact/decrypt" },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const computeUrl = Deno.env.get("FHE_COMPUTE_URL");
  const serviceToken = Deno.env.get("FHE_SERVICE_TOKEN");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!computeUrl || !serviceToken || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "FHE proxy is not configured" }, 503);
  }

  // ── 1. Parse & validate the envelope ────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const action = String(body.action ?? "");
  const route = ROUTES[action];
  if (!route) return json({ error: `Unsupported action: ${action}` }, 400);

  const nonce = String(body.nonce ?? "");
  const requestId = String(body.request_id ?? crypto.randomUUID());
  const timestamp = Number(body.timestamp ?? 0);
  const payload = (body.payload ?? {}) as Record<string, unknown>;

  // ── 2. Authenticate the client JWT or service_role key ──────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const token = authHeader.replace("Bearer ", "");
  // Nullable: a trusted server-to-server caller (e.g. pact-matcher) may have
  // no specific end-user context. `null` is valid for every ledger/job column
  // that references this (all nullable FKs to auth.users) — unlike a literal
  // placeholder string, which is not a valid UUID and would fail those inserts.
  let userId: string | null;
  let isServiceRole = false;

  if (token === serviceRoleKey) {
    isServiceRole = true;
    const hinted = req.headers.get("X-Tenant-Id") || (payload.tenant_id ? String(payload.tenant_id) : "");
    userId = hinted || null;
  } else {
    const authClient = createClient(supabaseUrl, anonKey ?? "", {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Invalid or expired session" }, 401);
    }
    userId = userData.user.id;
  }

  // service-role client bypasses RLS for ledger/job writes
  const admin = createClient(supabaseUrl, serviceRoleKey);


  // ── 3. Replay protection ────────────────────────────────────────────────
  if (!nonce || !timestamp) {
    return json({ error: "Missing nonce or timestamp" }, 400);
  }
  if (Math.abs(Date.now() - timestamp) > REPLAY_WINDOW_MS) {
    await recordEvent(admin, userId, null, "fhe_replay_detected", {
      reason: "timestamp_out_of_window",
    });
    return json({ error: "Request timestamp outside allowed window" }, 401);
  }
  const { error: nonceErr } = await admin
    .from("fhe_nonces")
    .insert({ nonce, request_id: requestId });
  if (nonceErr) {
    // Primary-key violation => nonce already used => replay.
    await recordEvent(admin, userId, null, "fhe_replay_detected", {
      reason: "nonce_reused",
    });
    return json({ error: "Replay detected" }, 409);
  }

  // ── 4. Optional job mirror (for async compute) ──────────────────────────
  let jobId: string | null = null;
  if (action === "submit_job") {
    const { data: jobRow, error: jobErr } = await admin
      .from("fhe_compute_jobs")
      .insert({
        user_id: userId,
        key_id: String(payload.key_id ?? "unknown"),
        operation: String(payload.operation ?? "unknown"),
        priority: Number(payload.priority ?? 1),
        timeout_seconds: Number(payload.timeout_seconds ?? 30),
        status: "queued",
      })
      .select("id")
      .single();
    if (jobErr) return json({ error: "Failed to create job" }, 500);
    jobId = jobRow.id as string;
    await recordEvent(admin, userId, jobId, "fhe_compute_started", {
      operation: String(payload.operation ?? "unknown"),
    });
  }

  // ── 5. Forward to the Rust microservice ─────────────────────────────────
  let upstream: Response;
  try {
    upstream = await fetch(`${computeUrl}${route.path}`, {
      method: route.method,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${serviceToken}`,
        // enforce tenant isolation server-side; omit when there's no specific
        // tenant (a trusted server caller like pact-matcher supplies arena_id
        // in the payload itself for pact endpoints, which ignore this header)
        ...(userId ? { "X-Tenant-Id": userId } : {}),
        "X-Request-Id": requestId,
      },
      body: JSON.stringify({ ...payload, tenant_id: userId, job_id: jobId }),
    });
  } catch (_e) {
    if (jobId) await failJob(admin, userId, jobId, "upstream_unreachable");
    return json({ error: "FHE compute service unreachable" }, 502);
  }

  const upstreamText = await upstream.text();
  let upstreamBody: unknown;
  try {
    upstreamBody = JSON.parse(upstreamText);
  } catch {
    upstreamBody = { raw: upstreamText };
  }

  if (!upstream.ok) {
    if (jobId) {
      await failJob(admin, userId, jobId, `upstream_${upstream.status}`);
    }
    return json({ error: "FHE compute failed", detail: upstreamBody }, 502);
  }

  // ── 6. Persist completion + audit ───────────────────────────────────────
  if (action === "submit_job" && jobId) {
    await recordEvent(admin, userId, jobId, "fhe_compute_completed", {});
  }

  // ── 6b. Key-metadata lifecycle transitions ──────────────────────────────
  // Metadata rows hold the non-secret evaluation-key fingerprint + status only
  // (never key material). The fingerprint is the stable per-key id; event rows
  // stay fingerprint-free per the ledger's non-sensitive-metadata rule.
  const nowIso = new Date().toISOString();
  const fingerprint = String(
    (upstreamBody as Record<string, unknown>)?.public_fingerprint ?? "",
  );

  if ((action === "generate_keys" || action === "rotate_keys") && fingerprint) {
    if (action === "rotate_keys") {
      // Retire any currently-active keys before recording the new one.
      await admin
        .from("fhe_key_metadata")
        .update({ status: "rotated", rotated_at: nowIso })
        .eq("user_id", userId)
        .eq("status", "active");
    }
    await admin.from("fhe_key_metadata").upsert(
      {
        user_id: userId,
        key_id: fingerprint,
        public_fingerprint: fingerprint,
        status: "active",
      },
      { onConflict: "user_id,key_id" },
    );
    await recordEvent(
      admin,
      userId,
      null,
      action === "rotate_keys" ? "fhe_key_rotated" : "fhe_key_generated",
      {},
    );
  } else if (action === "revoke_keys") {
    await admin
      .from("fhe_key_metadata")
      .update({ status: "revoked", revoked_at: nowIso })
      .eq("user_id", userId)
      .eq("status", "active");
    await recordEvent(admin, userId, null, "fhe_key_revoked", {});
  }

  return json({ request_id: requestId, job_id: jobId, result: upstreamBody });
});

// ── helpers ────────────────────────────────────────────────────────────────
async function recordEvent(
  admin: AdminClient,
  userId: string | null,
  jobId: string | null,
  eventType: string,
  metadata: Record<string, unknown>,
) {
  // metadata must remain aggregate/non-sensitive — never ciphertext or keys.
  await admin.from("fhe_events").insert({
    user_id: userId,
    job_id: jobId,
    event_type: eventType,
    metadata,
  });
}

async function failJob(
  admin: AdminClient,
  userId: string | null,
  jobId: string,
  reason: string,
) {
  await admin
    .from("fhe_compute_jobs")
    .update({ status: "failed", error: reason })
    .eq("id", jobId);
  await recordEvent(admin, userId, jobId, "fhe_compute_failed", { reason });
}
