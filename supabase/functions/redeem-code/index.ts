// Supabase Edge Function: redeem-code
//
// New path: POST { token, pin } — token is the unguessable secret, pin is
// a 2-digit confirmation. Legacy path: POST { code } with an 8-character
// code still works for rows minted before the token+pin change.
//
// Pin-only redemption is rejected on purpose (100 combinations).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

async function sha256Hex(message: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const codeSalt = Deno.env.get("REDEMPTION_CODE_SALT");
  const ipSalt = Deno.env.get("BURN_FILES_IP_SALT");
  if (!supabaseUrl || !serviceRoleKey || !codeSalt || !ipSalt) {
    return json({ error: "redeem-code is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const token = String(body.token ?? "").trim().toLowerCase();
  const pin = String(body.pin ?? "").trim();
  const legacyCode = String(body.code ?? "").trim().toUpperCase();

  const usingTokenPin = token.length === 32 && /^\d{2}$/.test(pin);
  const usingLegacy = !usingTokenPin && legacyCode.length >= 6;

  if (!usingTokenPin && !usingLegacy) {
    return json({
      error: "Open the link you were sent, then enter the 2-digit code.",
    }, 400);
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
    .in("config_key", ["redeem_rate_limit_per_hour", "redeem_rate_limit_window_minutes"]);
  const cfg = (key: string, fallback: number): number => {
    const row = configRows?.find((r: { config_key: string; config_value: unknown }) => r.config_key === key);
    return row ? Number(row.config_value) : fallback;
  };
  const rateLimitPerHour = cfg("redeem_rate_limit_per_hour", 10);
  const rateLimitWindowMinutes = cfg("redeem_rate_limit_window_minutes", 60);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);

  const { data: allowed, error: rateErr } = await admin.rpc("check_and_increment_redeem_rate", {
    p_ip_hash: ipHash,
    p_limit: rateLimitPerHour,
    p_window_minutes: rateLimitWindowMinutes,
  });
  if (rateErr) {
    console.error("redeem-code: rate limit check failed", rateErr);
    return json({ error: "Could not process this code" }, 500);
  }
  if (!allowed) {
    return json({ error: "Too many attempts from this network. Please try again later." }, 429);
  }

  let claimed: Record<string, unknown> | null = null;
  if (usingTokenPin) {
    const tokenHash = await sha256Hex(token);
    const pinHash = await sha256Hex(`no-sus:redemption:pin:v1:${token}:${pin}`);
    const { data, error } = await admin.rpc("claim_redemption_token", {
      p_token_hash: tokenHash,
      p_pin_hash: pinHash,
    });
    if (error) {
      console.error("redeem-code: token claim RPC failed", error);
      return json({ error: "Could not process this code" }, 500);
    }
    claimed = data;
  } else {
    const codeHash = await hmacHex(legacyCode, codeSalt);
    const { data, error } = await admin.rpc("claim_redemption_code", {
      p_code_hash: codeHash,
    });
    if (error) {
      console.error("redeem-code: claim RPC failed", error);
      return json({ error: "Could not process this code" }, 500);
    }
    claimed = data;
  }

  if (!claimed?.id) {
    return json({ error: "Invalid or expired code" }, 410);
  }

  return json({
    target_kind: claimed.target_kind,
    target_id: claimed.target_id,
    key_hex: claimed.key_hex,
    iv_hex: claimed.iv_hex,
    key_material_ciphertext: claimed.key_material_ciphertext,
    key_material_iv_hex: claimed.key_material_iv_hex,
  });
});
