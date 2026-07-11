// Backend calls for the landing page's real burn tools. Mirrors the Flutter
// clients exactly:
//   notes → direct anonymous REST insert into burn_notes
//           (burn_note_creator_screen.dart)
//   files → burn-file-init → PUT ciphertext to signed URL → burn-file-confirm
//           (burn_file_client.dart / burn_file_creator_screen.dart)
import { APP_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";
import {
  bytesToHex,
  encryptFilePayload,
  encryptNote,
  generateKeyMaterial,
  packBurnFilePayload,
} from "./burnCrypto";

export const NOTE_MAX_CHARS = 10000;
export const FILE_MAX_BYTES = 50 * 1024 * 1024; // enforced again server-side

function shareLink(kind: "burn" | "burnfile", id: string, key: Uint8Array, iv: Uint8Array): string {
  // Key + IV live in the fragment — never transmitted to any server.
  return `${APP_URL}#/${kind}/${id}?k=${bytesToHex(key)}&v=${bytesToHex(iv)}`;
}

/** Creates a real self-destructing note; returns the one-time link. */
export async function createBurnNote(text: string): Promise<string> {
  const { key, iv } = generateKeyMaterial();
  const ciphertext = await encryptNote(text, key, iv);
  const noteId = globalThis.crypto.randomUUID();

  const res = await fetch(`${SUPABASE_URL}/rest/v1/burn_notes`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SUPABASE_ANON_KEY,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      Prefer: "return=minimal",
    },
    body: JSON.stringify({ id: noteId, ciphertext }),
  });
  if (!res.ok) {
    throw new Error("Could not create the note. Please try again in a moment.");
  }
  return shareLink("burn", noteId, key, iv);
}

export type BurnFileProgress =
  | { phase: "encrypting" }
  | { phase: "uploading" }
  | { phase: "sealing" };

/** Encrypts + uploads a real one-time file drop; returns the one-time link. */
export async function createBurnFile(
  file: File,
  expiryHours: number,
  onProgress: (p: BurnFileProgress) => void,
): Promise<string> {
  if (file.size <= 0) throw new Error("That file looks empty.");
  if (file.size > FILE_MAX_BYTES) {
    throw new Error("Too large — Burn Files are capped at 50MB.");
  }

  onProgress({ phase: "encrypting" });
  const { key, iv } = generateKeyMaterial();
  const packed = packBurnFilePayload(
    file.name,
    file.type || "application/octet-stream",
    new Uint8Array(await file.arrayBuffer()),
  );
  const ciphertext = await encryptFilePayload(packed, key, iv);

  const headers = {
    "Content-Type": "application/json",
    apikey: SUPABASE_ANON_KEY,
  };

  onProgress({ phase: "uploading" });
  const initRes = await fetch(`${SUPABASE_URL}/functions/v1/burn-file-init`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      declared_size_bytes: ciphertext.length,
      expiry_hours: expiryHours,
    }),
  });
  const init = await initRes.json();
  if (!initRes.ok) {
    throw new Error(init.error ?? "Could not start this upload.");
  }

  const uploadRes = await fetch(init.signed_upload_url, {
    method: "PUT",
    headers: { "Content-Type": "application/octet-stream" },
    body: ciphertext as BodyInit,
  });
  if (!uploadRes.ok) {
    throw new Error("Upload failed. Please try again.");
  }

  onProgress({ phase: "sealing" });
  const confirmRes = await fetch(
    `${SUPABASE_URL}/functions/v1/burn-file-confirm`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ file_id: init.file_id }),
    },
  );
  if (!confirmRes.ok) {
    const confirm = await confirmRes.json().catch(() => ({}));
    throw new Error(confirm.error ?? "Could not seal this upload.");
  }

  return shareLink("burnfile", init.file_id, key, iv);
}
