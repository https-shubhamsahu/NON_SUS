// Opens a borrowed-computer Go session. The desk sends the sid it already
// put in the QR; we store only the sha256 and a short expiry. verify_jwt is
// false because the desk has no account. The phone claims the row later.
//
// IP hashing reuses BURN_FILES_IP_SALT so this does not need a new secret.

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
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(message));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function validSid(sid: string): boolean {
  if (!/^[A-Za-z0-9_-]{22}$/.test(sid)) return false;
  const bin = atob(sid.replace(/-/g, "+").replace(/_/g, "/") + "==");
  return bin.length === 16;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const ipSalt = Deno.env.get("BURN_FILES_IP_SALT");
  if (!supabaseUrl || !serviceRoleKey || !ipSalt) {
    return json({ error: "go-session-open is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const sid = typeof body.sid === "string" ? body.sid : "";
  if (!validSid(sid)) return json({ error: "Bad session" }, 400);

  const { data: flag } = await admin
    .from("feature_flags")
    .select("is_active")
    .eq("flag_key", "nosus_address_enabled")
    .maybeSingle();
  if (!flag || flag.is_active !== true) return json({ error: "Not found" }, 404);

  const sidHash = await sha256Hex(sid);
  const { data: existing } = await admin
    .from("go_sessions")
    .select("state, expires_at")
    .eq("sid_hash", sidHash)
    .maybeSingle();
  if (
    existing &&
    existing.state !== "ended" &&
    new Date(existing.expires_at).getTime() > Date.now()
  ) {
    return json({ ok: true });
  }

  const { data: configRows } = await admin
    .from("remote_configs")
    .select("config_key, config_value")
    .in("config_key", ["go_qr_ttl_s", "go_open_rate_per_hour"]);
  const cfg = (key: string, fallback: number): number => {
    const row = configRows?.find((r: { config_key: string }) => r.config_key === key);
    const n = row ? Number(row.config_value) : fallback;
    return Number.isFinite(n) ? n : fallback;
  };
  const ttlSeconds = cfg("go_qr_ttl_s", 120);
  const perHour = cfg("go_open_rate_per_hour", 30);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);
  const { data: allowed, error: rateErr } = await admin.rpc("check_and_increment_go_open_rate", {
    p_ip_hash: ipHash,
    p_limit: perHour,
    p_window_minutes: 60,
  });
  if (rateErr) {
    console.error("go-session-open: rate limit failed", rateErr);
    return json({ error: "Could not open a session" }, 500);
  }
  if (!allowed) return json({ error: "Too many sessions from this network." }, 429);

  const expires = new Date(Date.now() + ttlSeconds * 1000).toISOString();
  const { error: writeErr } = existing
    ? await admin
        .from("go_sessions")
        .update({ state: "open", owner_user_id: null, expires_at: expires, created_at: new Date().toISOString() })
        .eq("sid_hash", sidHash)
    : await admin.from("go_sessions").insert({
        sid_hash: sidHash,
        state: "open",
        expires_at: expires,
      });
  if (writeErr) {
    console.error("go-session-open: write failed", writeErr);
    return json({ error: "Could not open a session" }, 500);
  }

  // ponytail: sweep yesterday's rows on the way out. A cron job when this table is busy.
  await admin
    .from("go_sessions")
    .delete()
    .lt("expires_at", new Date(Date.now() - 24 * 3600 * 1000).toISOString());

  return json({ ok: true });
});
