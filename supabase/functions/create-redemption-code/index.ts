// Supabase Edge Function: create-redemption-code
//
// Mints a pairing record for an existing Burn Note or Burn File.
// The client sends SHA-256 lookup hashes plus client-side encrypted key
// material. The service never receives a pairing secret or a Burn key.
//
// POST { target_kind: 'note'|'file', target_id, token_hash, pin_hash,
//        key_material_ciphertext, key_material_iv_hex } -> { expires_at }
//
// Older clients retain the documented, server-held-key 8-character path.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_INSERT_ATTEMPTS = 5;
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

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

function generateLegacyCode(): string {
  const bytes = new Uint8Array(8);
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
  const tokenHash = String(body.token_hash ?? "").trim().toLowerCase();
  const pinHash = String(body.pin_hash ?? "").trim().toLowerCase();
  const keyMaterialCiphertext = String(body.key_material_ciphertext ?? "").trim().toLowerCase();
  const keyMaterialIvHex = String(body.key_material_iv_hex ?? "").trim().toLowerCase();
  const legacyKeyHex = String(body.key_hex ?? "").trim();
  const legacyIvHex = String(body.iv_hex ?? "").trim();
  const pairingRequest =
    /^[a-f0-9]{64}$/.test(tokenHash) && /^[a-f0-9]{64}$/.test(pinHash) &&
    /^[a-f0-9]+$/.test(keyMaterialCiphertext) && keyMaterialCiphertext.length % 2 === 0 &&
    /^[a-f0-9]{32}$/.test(keyMaterialIvHex);
  const legacyRequest = legacyKeyHex.length > 0 && legacyIvHex.length > 0;
  if (targetKind !== "note" && targetKind !== "file") {
    return json({ error: "target_kind must be 'note' or 'file'" }, 400);
  }
  if (!targetId || (!pairingRequest && !legacyRequest)) {
    return json({ error: "Missing pairing envelope" }, 400);
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
    const legacyCode = pairingRequest ? null : generateLegacyCode();
    const row = pairingRequest
      ? {
          code_hash: tokenHash,
          pin_hash: pinHash,
          target_kind: targetKind,
          target_id: targetId,
          key_material_ciphertext: keyMaterialCiphertext,
          key_material_iv_hex: keyMaterialIvHex,
          expires_at: expiresAt,
        }
      : {
          code_hash: await hmacHex(legacyCode!, codeSalt),
          target_kind: targetKind,
          target_id: targetId,
          key_hex: legacyKeyHex,
          iv_hex: legacyIvHex,
          expires_at: expiresAt,
        };
    const { error: insertErr } = await admin.from("burn_redemption_codes").insert(row);

    if (!insertErr) {
      return json(pairingRequest ? { expires_at: expiresAt } : { code: legacyCode, expires_at: expiresAt });
    }
    if (insertErr.code !== "23505") {
      console.error("create-redemption-code: failed to insert row", insertErr);
      return json({ error: "Could not create a redemption code" }, 502);
    }
  }

  console.error("create-redemption-code: exhausted retries on token collision");
  return json({ error: "Could not create a redemption code" }, 502);
});
