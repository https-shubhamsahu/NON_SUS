// Supabase Edge Function: create-redemption-code
//
// Mints a short, human-typeable code as an ALTERNATE way to retrieve the
// key/IV for an existing Burn Note or Burn File — the link-based path (key/
// IV in the URL fragment, never touching the server) is unaffected and
// keeps its zero-knowledge guarantee. This is a deliberate, informed
// exception for this one path: the server temporarily holds the key,
// indexed by a hash of the code, for a short window.
// See supabase/migrations/20260713000000_burn_redemption_codes.sql for the
// full design rationale.
//
// POST { target_kind: 'note'|'file', target_id, key_hex, iv_hex } ->
//   { code, expires_at }
//
// Responsibilities:
//   1. Check the burn_redemption_codes_enabled kill-switch.
//   2. Verify the target actually exists and hasn't already been
//      consumed/expired — no point minting a code for dead content.
//   3. Generate an 8-character code (same 32-symbol alphabet already used
//      for group invite codes — one consistent "type this into NO SUS"
//      style app-wide), hash it, and store the row with expiry capped to
//      the underlying content's own expiry.
//   4. Return the plaintext code once — it is never stored.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Same alphabet as groups_screen.dart's _generateInviteCode — excludes
// 0/O/1/I/L to avoid ambiguity when a code is read aloud or handwritten.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;
const MAX_INSERT_ATTEMPTS = 5; // collision odds are ~1-in-1.1-trillion; this just guards the freak case

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacHex(message: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function generateCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => CODE_ALPHABET[b % CODE_ALPHABET.length]).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const codeSalt = Deno.env.get("REDEMPTION_CODE_SALT");
  if (!supabaseUrl || !serviceRoleKey || !codeSalt) {
    return json({ error: "create-redemption-code is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const targetKind = String(body.target_kind ?? "");
  const targetId = String(body.target_id ?? "").trim();
  const keyHex = String(body.key_hex ?? "").trim();
  const ivHex = String(body.iv_hex ?? "").trim();
  if (targetKind !== "note" && targetKind !== "file") {
    return json({ error: "target_kind must be 'note' or 'file'" }, 400);
  }
  if (!targetId || !keyHex || !ivHex) {
    return json({ error: "Missing target_id, key_hex, or iv_hex" }, 400);
  }

  const { data: flag } = await admin
    .from("feature_flags")
    .select("is_active")
    .eq("flag_key", "burn_redemption_codes_enabled")
    .maybeSingle();
  if (flag && flag.is_active === false) {
    return json({ error: "Redemption codes are temporarily disabled" }, 503);
  }

  const { data: configRows } = await admin
    .from("remote_configs")
    .select("config_key, config_value")
    .eq("config_key", "redeem_code_ttl_minutes");
  const ttlMinutes = configRows?.length ? Number(configRows[0].config_value) : 20;

  // Verify the target still exists and hasn't already been consumed/expired
  // — a code for dead content would just be a confusing dead end.
  let targetExpiresAt: string | null = null;
  if (targetKind === "file") {
    const { data: fileRow } = await admin
      .from("burn_files")
      .select("expires_at, consumed_at")
      .eq("id", targetId)
      .maybeSingle();
    if (!fileRow || fileRow.consumed_at || new Date(fileRow.expires_at) <= new Date()) {
      return json({ error: "This file is no longer available" }, 404);
    }
    targetExpiresAt = fileRow.expires_at;
  } else {
    const { data: noteRow } = await admin
      .from("burn_notes")
      .select("expires_at")
      .eq("id", targetId)
      .maybeSingle();
    if (!noteRow || new Date(noteRow.expires_at) <= new Date()) {
      return json({ error: "This note is no longer available" }, 404);
    }
    targetExpiresAt = noteRow.expires_at;
  }

  const ttlExpiry = new Date(Date.now() + ttlMinutes * 60 * 1000);
  const targetExpiry = new Date(targetExpiresAt);
  const expiresAt = (ttlExpiry < targetExpiry ? ttlExpiry : targetExpiry).toISOString();

  for (let attempt = 0; attempt < MAX_INSERT_ATTEMPTS; attempt++) {
    const code = generateCode();
    const codeHash = await hmacHex(code, codeSalt);

    const { error: insertErr } = await admin.from("burn_redemption_codes").insert({
      code_hash: codeHash,
      target_kind: targetKind,
      target_id: targetId,
      key_hex: keyHex,
      iv_hex: ivHex,
      expires_at: expiresAt,
    });

    if (!insertErr) {
      return json({ code, expires_at: expiresAt });
    }
    // 23505 = unique_violation on code_hash — vanishingly unlikely, just retry with a new code.
    if (insertErr.code !== "23505") {
      console.error("create-redemption-code: failed to insert row", insertErr);
      return json({ error: "Could not create a redemption code" }, 502);
    }
  }

  console.error("create-redemption-code: exhausted retries on code collision");
  return json({ error: "Could not create a redemption code" }, 502);
});
