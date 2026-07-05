// Supabase Edge Function: sealed-api
//
// The trusted orchestrator for Sealed (reciprocity-gated intent graph).
// Flutter -> (JWT) -> sealed-api -> (service token) -> fhe-compute (TFHE-rs).
//
// Actions:
//   create_arena  {name}                                  -> {arena_id, my_public_id}
//   seal          {arena_id, target_public_id, intent_kind} -> {status, matched}
//   create_invite {arena_id?}                             -> {code}
//   claim_invite  {code}                                  -> {arena_id?, my_public_id?}
//
// TRUST MODEL (interim, pre-M10 — see PROJECT_HANDOVER.md "Honesty Rule"):
//   The arena pact key lives in the Rust service's RAM (TENANT_KEY_STORE keyed
//   by arena_id). This function passes the caller's plaintext pick over TLS to
//   /pact/seal, stores ONLY the ciphertext, and never logs the pick. A match is
//   created ONLY when the FHE mutual-match predicate decrypts true. Post-M10,
//   sealing/decryption move on-device and this function stops seeing plaintext.
//
// PRIVACY RULES (load-bearing):
//   * Never log or persist a plaintext choice or ciphertext.
//   * Never return another member's seal, ciphertext, or non-mutual outcome.
//   * `matched` in the seal response reveals only what the matcher created in
//     `matches` (already visible to both parties via RLS + realtime).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AdminClient = any;

const INTENT_KINDS = new Set([
  "crush",
  "friend",
  "reconnect",
  "work_with",
  "hire",
  "invest",
  "partner",
]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Calls the Rust FHE service. Never logs payloads (they may contain choices). */
async function fhe(
  computeUrl: string,
  serviceToken: string,
  path: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const res = await fetch(`${computeUrl}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${serviceToken}`,
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = {};
  }
  if (!res.ok) {
    throw new Error(`fhe ${path} failed (${res.status})`);
  }
  return parsed;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const computeUrl = Deno.env.get("FHE_COMPUTE_URL");
  const serviceToken = Deno.env.get("FHE_SERVICE_TOKEN");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "sealed-api is not configured" }, 503);
  }

  // ── Authenticate caller ────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);
  const authClient = createClient(supabaseUrl, anonKey ?? "", {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "Invalid or expired session" }, 401);
  }
  const userId = userData.user.id as string;
  const admin: AdminClient = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const action = String(body.action ?? "");
  const payload = (body.payload ?? {}) as Record<string, unknown>;

  try {
    switch (action) {
      // ────────────────────────────────────────────────────────────────────
      case "create_arena": {
        const name = String(payload.name ?? "").trim();
        if (!name) return json({ error: "Arena name required" }, 400);

        const { data: arena, error: arenaErr } = await admin
          .from("arenas")
          .insert({ name, kind: "community", created_by: userId })
          .select("id")
          .single();
        if (arenaErr) return json({ error: "Failed to create arena" }, 500);
        const arenaId = arena.id as string;

        // Provision the arena pact key (best-effort: key material is created
        // lazily by the Rust service on first use either way).
        if (computeUrl && serviceToken) {
          try {
            const keyRes = await fetch(`${computeUrl}/keys/generate`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${serviceToken}`,
                "X-Tenant-Id": arenaId,
              },
              body: JSON.stringify({ security_level: 128, parameter_set: "default" }),
            });
            const keyBody = await keyRes.json().catch(() => ({}));
            const fp = String(keyBody?.public_fingerprint ?? "");
            if (fp) {
              await admin.from("arenas").update({ key_fingerprint: fp }).eq("id", arenaId);
            }
          } catch (_e) {
            // non-fatal: lazy creation covers it
          }
        }

        // Creator joins with public id 1 (0 is the "no pick" sentinel).
        const { error: memberErr } = await admin
          .from("arena_members")
          .insert({ arena_id: arenaId, user_id: userId, arena_public_id: 1 });
        if (memberErr) return json({ error: "Failed to join new arena" }, 500);

        return json({ arena_id: arenaId, my_public_id: 1 });
      }

      // ────────────────────────────────────────────────────────────────────
      case "seal": {
        if (!computeUrl || !serviceToken) {
          return json({ error: "FHE compute is not configured" }, 503);
        }
        const arenaId = String(payload.arena_id ?? "");
        const targetPublicId = Number(payload.target_public_id ?? 0);
        const intentKind = String(payload.intent_kind ?? "crush");
        if (!arenaId || !Number.isInteger(targetPublicId) || targetPublicId <= 0) {
          return json({ error: "arena_id and a positive target_public_id required" }, 400);
        }
        if (!INTENT_KINDS.has(intentKind)) {
          return json({ error: "Unknown intent_kind" }, 400);
        }

        // Caller must be a member; resolve their public id.
        const { data: me } = await admin
          .from("arena_members")
          .select("arena_public_id")
          .eq("arena_id", arenaId)
          .eq("user_id", userId)
          .maybeSingle();
        if (!me) return json({ error: "Not a member of this arena" }, 403);
        const myPublicId = me.arena_public_id as number;
        if (myPublicId === targetPublicId) {
          return json({ error: "You cannot seal yourself" }, 400);
        }

        // Target must exist in the arena.
        const { data: target } = await admin
          .from("arena_members")
          .select("user_id")
          .eq("arena_id", arenaId)
          .eq("arena_public_id", targetPublicId)
          .maybeSingle();
        if (!target) return json({ error: "No such member in this arena" }, 400);

        // Seal under the ARENA pact key (plaintext exists only in transit).
        const sealRes = await fhe(computeUrl, serviceToken, "/pact/seal", {
          arena_id: arenaId,
          choice: targetPublicId,
        });
        const sealedChoice = String(sealRes.sealed_choice ?? "");
        if (!sealedChoice) return json({ error: "Sealing failed" }, 502);

        // Upsert my seal (re-sealing replaces the previous pick).
        const { error: upsertErr } = await admin.from("seals").upsert(
          {
            arena_id: arenaId,
            sealer_id: userId,
            sealed_choice: sealedChoice,
            intent_kind: intentKind,
            status: "pending",
          },
          { onConflict: "arena_id,sealer_id,intent_kind" },
        );
        if (upsertErr) return json({ error: "Failed to store seal" }, 500);

        await recordEvent(admin, userId, "fhe_discovery_started", { intent: intentKind });

        // ── Matcher pass: evaluate my seal against every other pending seal ──
        const { data: candidates } = await admin
          .from("seals")
          .select("sealer_id, sealed_choice")
          .eq("arena_id", arenaId)
          .eq("intent_kind", intentKind)
          .eq("status", "pending")
          .neq("sealer_id", userId);

        let matched = false;
        for (const cand of candidates ?? []) {
          const { data: candMember } = await admin
            .from("arena_members")
            .select("arena_public_id")
            .eq("arena_id", arenaId)
            .eq("user_id", cand.sealer_id)
            .maybeSingle();
          if (!candMember) continue;

          const evalRes = await fhe(computeUrl, serviceToken, "/pact/evaluate", {
            arena_id: arenaId,
            a_choice: sealedChoice,
            a_id: myPublicId,
            b_choice: cand.sealed_choice,
            b_id: candMember.arena_public_id,
          });
          const encryptedMatch = String(evalRes.encrypted_match ?? "");
          if (!encryptedMatch) continue;

          const decRes = await fhe(computeUrl, serviceToken, "/pact/decrypt", {
            arena_id: arenaId,
            encrypted_match: encryptedMatch,
          });
          if (decRes.mutual !== true) continue; // non-mutual: reveal nothing

          // Mutual! Create the match (ordered pair) and flip both seals.
          const [a, b] = [userId, cand.sealer_id as string].sort();
          const { error: matchErr } = await admin.from("matches").insert({
            arena_id: arenaId,
            user_a: a,
            user_b: b,
            intent_kind: intentKind,
          });
          if (matchErr && !String(matchErr.message ?? "").includes("duplicate")) {
            continue;
          }
          await admin
            .from("seals")
            .update({ status: "matched" })
            .eq("arena_id", arenaId)
            .eq("intent_kind", intentKind)
            .in("sealer_id", [userId, cand.sealer_id]);
          matched = true;
          await recordEvent(admin, userId, "fhe_discovery_completed", { intent: intentKind });
          break; // one seal -> at most one mutual pick
        }

        return json({ status: "sealed", matched });
      }

      // ────────────────────────────────────────────────────────────────────
      case "create_invite": {
        const arenaId = payload.arena_id ? String(payload.arena_id) : null;
        if (arenaId) {
          const { data: me } = await admin
            .from("arena_members")
            .select("user_id")
            .eq("arena_id", arenaId)
            .eq("user_id", userId)
            .maybeSingle();
          if (!me) return json({ error: "Not a member of this arena" }, 403);
        }
        const code = crypto.randomUUID().replaceAll("-", "");
        const { error: invErr } = await admin.from("invites").insert({
          code,
          inviter_id: userId,
          arena_id: arenaId,
        });
        if (invErr) return json({ error: "Failed to create invite" }, 500);
        return json({ code });
      }

      // ────────────────────────────────────────────────────────────────────
      case "claim_invite": {
        const code = String(payload.code ?? "").trim();
        if (!code) return json({ error: "Invite code required" }, 400);

        const { data: invite } = await admin
          .from("invites")
          .select("code, inviter_id, arena_id, claimed_by")
          .eq("code", code)
          .maybeSingle();
        if (!invite) return json({ error: "Invalid invite code" }, 404);
        if (invite.claimed_by && invite.claimed_by !== userId) {
          return json({ error: "Invite already claimed" }, 409);
        }

        if (!invite.claimed_by) {
          await admin
            .from("invites")
            .update({ claimed_by: userId, claimed_at: new Date().toISOString() })
            .eq("code", code);
        }

        // Join the arena (next free public id; retry once on id collision).
        let myPublicId: number | null = null;
        const arenaId = invite.arena_id as string | null;
        if (arenaId) {
          const { data: existing } = await admin
            .from("arena_members")
            .select("arena_public_id")
            .eq("arena_id", arenaId)
            .eq("user_id", userId)
            .maybeSingle();
          if (existing) {
            myPublicId = existing.arena_public_id as number;
          } else {
            for (let attempt = 0; attempt < 2 && myPublicId === null; attempt++) {
              const { data: maxRow } = await admin
                .from("arena_members")
                .select("arena_public_id")
                .eq("arena_id", arenaId)
                .order("arena_public_id", { ascending: false })
                .limit(1)
                .maybeSingle();
              const next = ((maxRow?.arena_public_id as number | undefined) ?? 0) + 1;
              const { error: joinErr } = await admin
                .from("arena_members")
                .insert({ arena_id: arenaId, user_id: userId, arena_public_id: next });
              if (!joinErr) myPublicId = next;
            }
            if (myPublicId === null) {
              return json({ error: "Failed to join arena" }, 500);
            }
          }
        }

        return json({ arena_id: arenaId, my_public_id: myPublicId });
      }

      default:
        return json({ error: `Unsupported action: ${action}` }, 400);
    }
  } catch (_e) {
    // Never include payload details in errors (may reference choices).
    return json({ error: "sealed-api internal error" }, 500);
  }
});

// ── helpers ──────────────────────────────────────────────────────────────────
async function recordEvent(
  admin: AdminClient,
  userId: string,
  eventType: string,
  metadata: Record<string, unknown>,
) {
  // Aggregate, non-sensitive metadata only — never choices or ciphertext.
  await admin.from("fhe_events").insert({
    user_id: userId,
    event_type: eventType,
    metadata,
  });
}
