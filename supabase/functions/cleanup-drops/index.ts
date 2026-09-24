// Supabase Edge Function: cleanup-drops
//
// Invoked every 10 minutes by pg_cron via pg_net ('drops-cleanup-sweep' in
// supabase/migrations/20260924110000_nosus_drop.sql). Deletes the storage
// object first, then the row (envelopes and the sender hash cascade).
//
// Not public: gated by the same shared secret as cleanup-burn-files
// (x-cron-secret vs BURN_FILES_CRON_SECRET), so no new secret to manage.
//
// Deleted:
//   1. declined or expired drops
//   2. anything past expires_at (24h unanswered, 1h after accept)
//   3. 'uploading' rows older than 1 hour (visitor never confirmed)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

Deno.serve(async (req: Request) => {
  const cronSecret = Deno.env.get("BURN_FILES_CRON_SECRET");
  if (!cronSecret || req.headers.get("x-cron-secret") !== cronSecret) {
    return json({ error: "Unauthorized" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "cleanup-drops is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const nowIso = new Date().toISOString();
  const hourAgoIso = new Date(Date.now() - 3600 * 1000).toISOString();

  const [finished, expired, abandoned] = await Promise.all([
    admin.from("drops").select("id, storage_path").in("state", ["declined", "expired"]).limit(1000),
    admin.from("drops").select("id, storage_path").lt("expires_at", nowIso).limit(1000),
    admin.from("drops").select("id, storage_path").eq("state", "uploading").lt("created_at", hourAgoIso).limit(1000),
  ]);

  const rowsById = new Map<string, { id: string; storage_path: string }>();
  for (const result of [finished, expired, abandoned]) {
    if (result.error) {
      console.error("cleanup-drops: query failed", result.error);
      continue;
    }
    for (const row of result.data ?? []) rowsById.set(row.id, row);
  }

  const rows = Array.from(rowsById.values());
  let deleted = 0;
  for (const batch of chunk(rows, 100)) {
    const { error: removeErr } = await admin.storage.from("drops").remove(batch.map((r) => r.storage_path));
    if (removeErr) {
      console.error("cleanup-drops: storage removal failed", removeErr);
      continue; // keep the rows until the objects are surely gone
    }
    const { error: deleteErr } = await admin.from("drops").delete().in("id", batch.map((r) => r.id));
    if (deleteErr) {
      console.error("cleanup-drops: row deletion failed", deleteErr);
      continue;
    }
    deleted += batch.length;
  }

  return json({ deleted, candidates: rows.length });
});
