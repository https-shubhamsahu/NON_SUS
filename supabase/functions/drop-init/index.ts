// Drop, step 1. A visitor with no account asks to send one file.
// verify_jwt is false.
//
// POST { handle, code?, size } -> { dropId, uploadUrl, uploadToken, path, devices }
//
// `size` is the ciphertext size (plain + 28). drop_begin() does the checks
// in one transaction: rate limit per IP hash (wrong codes count), door open,
// door code, sender block, size cap, pending cap. The row starts as
// 'uploading'; drop-confirm makes it visible to the owner.
//
// IP hashing reuses BURN_FILES_IP_SALT, same as go-session-open.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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
    return json({ error: "drop-init is not configured" }, 503);
  }
  const admin = createClient(supabaseUrl, serviceRoleKey);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const handle = typeof body.handle === "string" ? body.handle.trim().toLowerCase() : "";
  const code = typeof body.code === "string" ? body.code.trim() : "";
  const size = Number(body.size);
  if (!/^[a-z0-9-]{4,20}$/.test(handle)) return json({ error: "This door is closed." }, 404);
  if (code && !/^[0-9]{4,8}$/.test(code)) return json({ error: "Wrong door code." }, 403);
  if (!Number.isSafeInteger(size) || size <= 0) return json({ error: "Missing file size" }, 400);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const ipHash = await hmacHex(ip, ipSalt);

  const { data, error } = await admin.rpc("drop_begin", {
    p_handle: handle,
    p_code: code || null,
    p_ip_hash: ipHash,
    p_size: size,
  });
  if (error || !data) {
    console.error("drop-init: drop_begin failed", error);
    return json({ error: "Could not start the upload." }, 500);
  }
  const result = data as {
    status: string;
    dropId?: string;
    path?: string;
    devices?: unknown[];
    max?: number;
  };
  switch (result.status) {
    case "ok":
      break;
    case "rate":
      return json({ error: "Too many tries from this network. Try again in an hour." }, 429);
    case "code":
      return json({ error: "Wrong door code." }, 403);
    case "size": {
      const mb = Math.floor(Number(result.max ?? 26214400) / 1048576);
      return json({ error: `That file is too big. The limit is ${mb} MB.` }, 413);
    }
    case "full":
      return json({ error: "Their inbox is full right now. Try again later." }, 429);
    default:
      return json({ error: "This door is closed." }, 404);
  }

  const dropId = result.dropId!;
  const path = result.path!;
  const { data: signed, error: signErr } = await admin.storage.from("drops").createSignedUploadUrl(path);
  if (signErr || !signed) {
    console.error("drop-init: signed upload url failed", signErr);
    await admin.from("drops").delete().eq("id", dropId);
    return json({ error: "Could not start the upload." }, 502);
  }

  return json({
    dropId,
    path,
    uploadUrl: signed.signedUrl,
    uploadToken: signed.token,
    devices: Array.isArray(result.devices) ? result.devices : [],
  });
});
