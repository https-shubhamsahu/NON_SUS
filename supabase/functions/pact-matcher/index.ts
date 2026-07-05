// Supabase Edge Function: pact-matcher
//
// Background matcher for Sealed.
// Triggered by a Supabase database webhook on the `seals` table or called directly.
//
// Responsibilities:
//   1. Parse new seal record (from webhook or direct payload).
//   2. If seal is pending, find candidate counter-seals in same arena/intent.
//   3. For each candidate, call `pact_evaluate` and `pact_decrypt` via `fhe-proxy`
//      using service_role authorization.
//   4. If mutual match is true, insert into `matches` (ordered user_a < user_b)
//      and update both seals' status to 'matched'.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-tenant-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export async function handleRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "pact-matcher is not configured" }, 503);
  }

  // Authorize: either the service role key (DB webhook on `seals` INSERT, or
  // another trusted server caller) or a valid end-user JWT. A JWT-authenticated
  // caller may only trigger matching for THEIR OWN seal (sealer_id must equal
  // their own uid, checked below once the record is parsed) — this endpoint
  // must never be usable to probe or reveal another user's match.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);
  const token = authHeader.replace(/^Bearer\s+/i, "");

  let callerUserId: string | null = null;
  if (token !== serviceRoleKey) {
    const authClient = createClient(supabaseUrl, anonKey ?? "", {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ error: "Unauthorized" }, 401);
    }
    callerUserId = userData.user.id;
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  // Handle both standard webhook payload and direct invocation payload
  const record = body.record || (body.table === "seals" ? body.record : body);
  if (!record || !record.id || !record.arena_id || !record.sealer_id || !record.sealed_choice) {
    return json({ error: "Missing required seal record fields" }, 400);
  }

  const sealId = record.id;
  const arenaId = record.arena_id;
  const sealerId = record.sealer_id;
  const sealedChoice = record.sealed_choice;
  const intentKind = record.intent_kind || "crush";
  const status = record.status;

  // A JWT-authenticated caller can only ever trigger matching for their own
  // seal — never for an arbitrary sealer_id (which would leak whether that
  // OTHER user has a match, to a party who isn't a participant in it).
  if (callerUserId && callerUserId !== sealerId) {
    return json({ error: "Forbidden: cannot trigger matching for another user" }, 403);
  }

  if (status !== "pending") {
    return json({ message: "Seal is not pending. Skipping matching.", matched: false });
  }

  // 1. Resolve sealer's public ID in this arena
  const { data: memberA, error: errA } = await admin
    .from("arena_members")
    .select("arena_public_id")
    .eq("arena_id", arenaId)
    .eq("user_id", sealerId)
    .maybeSingle();

  if (errA || !memberA) {
    console.error(`Failed to resolve sealer ${sealerId} public ID in arena ${arenaId}`, errA);
    return json({ error: "Failed to resolve sealer's public ID in arena", details: errA }, 400);
  }
  const aPubId = memberA.arena_public_id;

  // 2. Query other pending seals in the same arena for the same intent
  const { data: candidates, error: errCand } = await admin
    .from("seals")
    .select("sealer_id, sealed_choice")
    .eq("arena_id", arenaId)
    .eq("intent_kind", intentKind)
    .eq("status", "pending")
    .neq("sealer_id", sealerId);

  if (errCand) {
    console.error("Failed to query candidates:", errCand);
    return json({ error: "Failed to query candidates", details: errCand }, 500);
  }

  let matched = false;
  let matchedUserId: string | null = null;

  for (const cand of candidates || []) {
    // Resolve candidate public ID
    const { data: memberB, error: errB } = await admin
      .from("arena_members")
      .select("arena_public_id")
      .eq("arena_id", arenaId)
      .eq("user_id", cand.sealer_id)
      .maybeSingle();

    if (errB || !memberB) {
      console.warn(`Could not resolve public ID for candidate ${cand.sealer_id} in arena ${arenaId}`);
      continue;
    }
    const bPubId = memberB.arena_public_id;

    try {
      // 3. Call pact_evaluate via fhe-proxy
      const evalRes = await admin.functions.invoke("fhe-proxy", {
        body: {
          action: "pact_evaluate",
          nonce: crypto.randomUUID(),
          request_id: crypto.randomUUID(),
          timestamp: Date.now(),
          payload: {
            arena_id: arenaId,
            a_choice: sealedChoice,
            a_id: aPubId,
            b_choice: cand.sealed_choice,
            b_id: bPubId,
          },
        },
      });

      if (evalRes.error) {
        console.error(`pact_evaluate failed for candidates (${sealerId}, ${cand.sealer_id}):`, evalRes.error);
        continue;
      }

      const encryptedMatch = evalRes.data?.result?.encrypted_match;
      if (!encryptedMatch) {
        console.warn("pact_evaluate did not return an encrypted_match");
        continue;
      }

      // 4. Call pact_decrypt via fhe-proxy
      const decRes = await admin.functions.invoke("fhe-proxy", {
        body: {
          action: "pact_decrypt",
          nonce: crypto.randomUUID(),
          request_id: crypto.randomUUID(),
          timestamp: Date.now(),
          payload: {
            arena_id: arenaId,
            encrypted_match: encryptedMatch,
          },
        },
      });

      if (decRes.error) {
        console.error(`pact_decrypt failed for encrypted match:`, decRes.error);
        continue;
      }

      const mutual = decRes.data?.result?.mutual;
      if (mutual === true) {
        matched = true;
        matchedUserId = cand.sealer_id;
        break; // One seal can match with at most one target
      }
    } catch (e) {
      console.error(`Error during FHE evaluation/decryption sequence:`, e);
      continue;
    }
  }

  // 5. Commit match and status changes on mutual match
  if (matched && matchedUserId) {
    const [userA, userB] = [sealerId, matchedUserId].sort();

    const { error: matchErr } = await admin
      .from("matches")
      .insert({
        arena_id: arenaId,
        user_a: userA,
        user_b: userB,
        intent_kind: intentKind,
      });

    if (matchErr && !matchErr.message.includes("duplicate")) {
      console.error("Failed to insert match:", matchErr);
      return json({ error: "Failed to commit match", details: matchErr }, 500);
    }

    const { error: updateErr } = await admin
      .from("seals")
      .update({ status: "matched" })
      .eq("arena_id", arenaId)
      .eq("intent_kind", intentKind)
      .in("sealer_id", [sealerId, matchedUserId]);

    if (updateErr) {
      console.error("Failed to update seals status:", updateErr);
    }

    // Append FHE event logs (metadata only)
    await admin.from("fhe_events").insert([
      {
        user_id: sealerId,
        event_type: "fhe_discovery_completed",
        metadata: { intent: intentKind, matched: true },
      },
      {
        user_id: matchedUserId,
        event_type: "fhe_discovery_completed",
        metadata: { intent: intentKind, matched: true },
      },
    ]);

    return json({ matched: true, match: { user_a: userA, user_b: userB, intent_kind: intentKind } });
  }

  return json({ matched: false, message: "No mutual match found" });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
