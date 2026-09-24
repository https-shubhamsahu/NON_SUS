// Drop, step 2. The visitor uploaded the ciphertext to the signed URL and
// now hands over one sealed manifest per owner device. verify_jwt is false.
//
// POST { dropId, envelopes: [{ deviceKeyId, box }] } -> { ok: true }
//
// Checks the object really exists and its size equals what drop-init was
// told, then drop_finish() checks every envelope is for one of the owner's
// live device keys and flips the drop to 'pending'.
//
// No push notification: notifications.category only allows invites,
// membership, documents, security, and a new category would mean altering
// that constraint. The owner's Inbox listens on realtime instead.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

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
    return json({ error: "drop-confirm is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const dropId = typeof body.dropId === "string" ? body.dropId.toLowerCase() : "";
  if (!UUID.test(dropId)) return json({ error: "Unknown drop" }, 404);
  const envelopes = Array.isArray(body.envelopes) ? body.envelopes : null;
  if (!envelopes || envelopes.length < 1 || envelopes.length > 10) {
    return json({ error: "Missing envelopes" }, 400);
  }
  const clean = [];
  for (const raw of envelopes) {
    if (!raw || typeof raw !== "object") return json({ error: "Bad envelope" }, 400);
    const env = raw as Record<string, unknown>;
    if (typeof env.deviceKeyId !== "string" || typeof env.box !== "string") {
      return json({ error: "Bad envelope" }, 400);
    }
    clean.push({ deviceKeyId: env.deviceKeyId.toLowerCase(), box: env.box });
  }

  const { data: row } = await admin
    .from("drops")
    .select("id, storage_path, state, expires_at")
    .eq("id", dropId)
    .maybeSingle();
  if (!row || row.state !== "uploading" || new Date(row.expires_at).getTime() <= Date.now()) {
    return json({ error: "This upload expired. Send it again." }, 410);
  }

  const { data: listing, error: listErr } = await admin.storage
    .from("drops")
    .list("", { search: row.storage_path });
  const match = listing?.find((f) => f.name === row.storage_path);
  if (listErr || !match) {
    return json({ error: "The upload did not arrive. Send it again." }, 404);
  }
  const realSize = Number((match.metadata as { size?: number } | null)?.size ?? 0);

  const { data, error } = await admin.rpc("drop_finish", {
    p_drop_id: dropId,
    p_real_size: realSize,
    p_envelopes: clean,
  });
  if (error || !data) {
    console.error("drop-confirm: drop_finish failed", error);
    return json({ error: "Could not finish the upload." }, 500);
  }
  const status = (data as { status: string }).status;
  if (status === "ok") return json({ ok: true });

  // Anything else: remove the object and the row rather than leave a
  // half-made drop around.
  await admin.storage.from("drops").remove([row.storage_path]);
  await admin.from("drops").delete().eq("id", dropId).eq("state", "uploading");
  if (status === "size") return json({ error: "The upload size did not match. Send it again." }, 409);
  if (status === "envelopes") return json({ error: "Their devices changed. Send it again." }, 409);
  return json({ error: "This upload expired. Send it again." }, 410);
});
