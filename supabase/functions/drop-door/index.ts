// Drop: is this address's door open, and which device keys does a file get
// sealed to? verify_jwt is false because the visitor has no account.
//
// POST { handle } -> { open, needsCode, devices: [{ id, publicKey }] }
//
// An unknown handle and a closed door return the same answer, so this
// cannot be used to list which handles exist. Never returns the owner's
// user id, email, or name.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const CLOSED = { open: false, needsCode: false, devices: [] };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const ipSalt = Deno.env.get("BURN_FILES_IP_SALT");
  if (!supabaseUrl || !serviceRoleKey || !ipSalt) {
    return json({ error: "drop-door is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const handle = typeof body.handle === "string" ? body.handle.trim().toLowerCase() : "";
  if (!/^[a-z0-9-]{4,20}$/.test(handle)) return json(CLOSED);

  const { data: limit } = await admin
    .from("remote_configs")
    .select("config_value")
    .eq("config_key", "drop_door_rate_per_hour")
    .maybeSingle();
  const perHour = Number.isFinite(Number(limit?.config_value)) ? Number(limit?.config_value) : 120;

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);
  const { data: allowed, error: rateErr } = await admin.rpc("check_and_increment_drop_rate", {
    p_ip_hash: ipHash,
    p_kind: "door",
    p_limit: perHour,
    p_window_minutes: 60,
  });
  if (rateErr) {
    console.error("drop-door: rate limit failed", rateErr);
    return json({ error: "Could not check this address" }, 500);
  }
  if (!allowed) return json({ error: "Too many lookups from this network. Try again later." }, 429);

  const { data, error } = await admin.rpc("drop_door_public", { p_handle: handle });
  if (error) {
    console.error("drop-door: lookup failed", error);
    return json({ error: "Could not check this address" }, 500);
  }
  const door = (data ?? CLOSED) as { open?: boolean; needsCode?: boolean; devices?: unknown[] };
  if (!door.open) return json(CLOSED);
  return json({
    open: true,
    needsCode: door.needsCode === true,
    devices: Array.isArray(door.devices) ? door.devices : [],
  });
});
