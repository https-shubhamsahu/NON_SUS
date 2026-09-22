import { b64url, b64urlDecode, openBytes, randomBytes, sealBytes } from "./nosusSeal";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";

const FILE_MAX = 25 * 1024 * 1024;

async function post(path: string, body: unknown): Promise<Response> {
  return fetch(`${SUPABASE_URL}/functions/v1/${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  });
}

export async function openGoSession(sid: string): Promise<void> {
  const res = await post("go-session-open", { sid });
  if (!res.ok) {
    const payload = (await res.json().catch(() => ({}))) as { error?: string };
    throw new Error(payload.error || "Could not open a session");
  }
}

export async function uploadSealed(plain: Uint8Array): Promise<{ fileId: string; key: string; nonce: string }> {
  if (plain.byteLength > FILE_MAX) throw new Error("That file is over 25 MB.");
  const key = randomBytes(32);
  const nonce = randomBytes(12);
  const box = await sealBytes(key, nonce, plain);
  const initRes = await post("burn-file-init", { declared_size_bytes: box.byteLength, expiry_hours: 1 });
  const init = (await initRes.json()) as { error?: string; file_id?: string; signed_upload_url?: string };
  if (!initRes.ok || !init.file_id || !init.signed_upload_url) {
    throw new Error(init.error || "Could not start the upload.");
  }
  const put = await fetch(init.signed_upload_url, {
    method: "PUT",
    headers: { "Content-Type": "application/octet-stream" },
    body: box.buffer.slice(box.byteOffset, box.byteOffset + box.byteLength) as ArrayBuffer,
  });
  if (!put.ok) throw new Error("Could not upload.");
  const confirm = await post("burn-file-confirm", { file_id: init.file_id });
  if (!confirm.ok) throw new Error("Could not finish the upload.");
  return { fileId: init.file_id, key: b64url(key), nonce: b64url(nonce) };
}

export async function downloadSealed(fileId: string, key: string, nonce: string): Promise<Uint8Array> {
  const res = await post("burn-file-fetch", { file_id: fileId });
  const payload = (await res.json()) as { error?: string; signed_url?: string };
  if (!res.ok || !payload.signed_url) throw new Error(payload.error || "Could not fetch the file.");
  const file = await fetch(payload.signed_url);
  if (!file.ok) throw new Error("Could not download the file.");
  const bytes = new Uint8Array(await file.arrayBuffer());
  return openBytes(b64urlDecode(key), b64urlDecode(nonce), bytes);
}
