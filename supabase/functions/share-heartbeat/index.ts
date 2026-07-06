// Supabase Edge Function: share-heartbeat
//
// Receives periodic heartbeats from recipients viewing documents to update
// their last active timestamp or mark the session as ended.
//
// POST { view_event_id, close } -> { ok: true }

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "share-heartbeat is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const eventId = String(body.view_event_id ?? "").trim();
  const isClose = !!body.close;

  if (!eventId) return json({ error: "Missing view_event_id" }, 400);

  try {
    if (isClose) {
      await admin
        .from("share_view_events")
        .update({ ended_at: new Date().toISOString() })
        .eq("id", eventId);
    } else {
      await admin
        .from("share_view_events")
        .update({ last_heartbeat: new Date().toISOString() })
        .eq("id", eventId);
    }
  } catch (e) {
    console.error("share-heartbeat: Failed to update heartbeat", e);
    return json({ error: "Failed to update heartbeat" }, 500);
  }

  return json({ ok: true });
});
