// Drop: the owner's phone gets a short-lived download URL for the
// ciphertext of one of its own drops (to preview or to accept).
// verify_jwt is true; the user comes from the bearer token.
//
// POST { dropId } -> { url }
//
// The bytes are sealed with a key that only the owner's device can
// recover from its envelope, so this URL is useless without that device.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SIGNED_URL_TTL_SECONDS = 300;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "drop-fetch is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const jwt = (req.headers.get("authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "Sign in first" }, 401);
  const { data: auth, error: authErr } = await admin.auth.getUser(jwt);
  const userId = auth?.user?.id;
  if (authErr || !userId) return json({ error: "Sign in first" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const dropId = typeof body.dropId === "string" ? body.dropId.toLowerCase() : "";
  if (!UUID.test(dropId)) return json({ error: "Unknown drop" }, 404);

  const { data: enabled } = await admin.rpc("drop_enabled_for", { uid: userId });
  if (enabled !== true) return json({ error: "Not found" }, 404);

  const { data: row } = await admin
    .from("drops")
    .select("storage_path, state, expires_at")
    .eq("id", dropId)
    .eq("owner_user_id", userId)
    .maybeSingle();
  if (
    !row ||
    (row.state !== "pending" && row.state !== "accepted") ||
    new Date(row.expires_at).getTime() <= Date.now()
  ) {
    return json({ error: "This drop is gone." }, 410);
  }

  const { data: signed, error: signErr } = await admin.storage
    .from("drops")
    .createSignedUrl(row.storage_path, SIGNED_URL_TTL_SECONDS);
  if (signErr || !signed?.signedUrl) {
    console.error("drop-fetch: sign failed", signErr);
    return json({ error: "Could not get the file." }, 502);
  }
  return json({ url: signed.signedUrl });
});
