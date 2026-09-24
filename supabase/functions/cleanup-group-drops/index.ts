// Supabase Edge Function: cleanup-group-drops
//
// Invoked hourly by pg_cron via pg_net (the 'group-drops-files-cleanup' job
// in supabase/migrations/20260924120000_group_drops.sql). Deletes Group drops
// attachments older than remote_configs.group_drops_file_retention_days (7)
// from the private `group-drops` bucket. Messages are purged in SQL by the
// 'group-drops-message-purge' job; storage objects need the Storage API,
// which is why this function exists.
//
// Not a public endpoint: gated by the same shared cron secret as
// cleanup-burn-files (BURN_FILES_CRON_SECRET, vault 'burn_files_cron_secret').
// The objects are ciphertext; this function never sees a key.

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
    return json({ error: "cleanup-group-drops is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data, error } = await admin.rpc("group_drops_expired_objects", {
    p_limit: 2000,
  });
  if (error) {
    console.error("cleanup-group-drops: query failed", error);
    return json({ error: "query failed" }, 500);
  }

  const names = ((data ?? []) as { name: string }[])
    .map((row) => row.name)
    .filter((name) => typeof name === "string" && name.length > 0);

  let deleted = 0;
  for (const batch of chunk(names, 100)) {
    const { error: removeErr } = await admin.storage.from("group-drops").remove(batch);
    if (removeErr) {
      console.error("cleanup-group-drops: storage removal failed for batch", removeErr);
      continue;
    }
    deleted += batch.length;
  }

  return json({ deleted, candidates: names.length });
});
