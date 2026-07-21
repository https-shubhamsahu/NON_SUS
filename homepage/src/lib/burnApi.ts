// Backend calls for the landing page's real burn tools. Mirrors the Flutter
// clients exactly:
//   notes → direct anonymous REST insert into burn_notes
//           (burn_note_creator_screen.dart)
//   files → burn-file-init → PUT ciphertext to signed URL → burn-file-confirm
//           (burn_file_client.dart / burn_file_creator_screen.dart)
//   codes → create-redemption-code / redeem-code
//           (redemption_code_client.dart) — see
//           supabase/migrations/20260713000000_burn_redemption_codes.sql for
//           why this path trades zero-knowledge for a short, typeable code:
//           the server briefly holds the key/IV, compensated by a short
//           expiry, single-use, and rate limiting. The link stays untouched
//           and keeps its original guarantee.
import { APP_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";
import {
  bytesToHex,
  encryptFilePayload,
  encryptNote,
  generateKeyMaterial,
  packBurnFilePayload,
} from "./burnCrypto";

export const NOTE_MAX_CHARS = 10000;
// Kept in sync with remote_configs.burn_files_max_size_bytes (server is the
// authoritative enforcement point — this is only the client-side pre-flight
// check, so the browser fails fast instead of encrypting/uploading a file
// the server will reject anyway). The Flutter app additionally supports
// sharing multiple files under one 25MB combined link — this landing-page
// tool is still single-file only.
export const FILE_MAX_BYTES = 25 * 1024 * 1024;

export type BurnResult = { link: string; codePromise: Promise<string | null> };

function shareLink(kind: "burn" | "burnfile", id: string, key: Uint8Array, iv: Uint8Array): string {
  // Key + IV live in the fragment — never transmitted to any server.
  return `${APP_URL}#/${kind}/${id}?k=${bytesToHex(key)}&v=${bytesToHex(iv)}`;
}

/** Best-effort: mints a short redemption code for an already-created note/file.
 * Never throws — the link already works on its own, so a hiccup here should
 * just leave the code section hidden, not fail the whole operation. */
async function mintCode(
  targetKind: "note" | "file",
  targetId: string,
  keyHex: string,
  ivHex: string,
): Promise<string | null> {
  try {
    const res = await fetch(`${SUPABASE_URL}/functions/v1/create-redemption-code`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
      body: JSON.stringify({
        target_kind: targetKind,
        target_id: targetId,
        key_hex: keyHex,
        iv_hex: ivHex,
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    return typeof data.code === "string" ? data.code : null;
  } catch {
    return null;
  }
}

/** Creates a real self-destructing note; returns the one-time link + a short redemption code. */
export async function createBurnNote(text: string): Promise<BurnResult> {
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

  const keyHex = bytesToHex(key);
  const ivHex = bytesToHex(iv);
  // Not awaited: the link is the actual deliverable and is already ready.
  // The code is a secondary convenience — let it arrive whenever it arrives
  // instead of making every share wait on a 4th network round trip.
  const codePromise = mintCode("note", noteId, keyHex, ivHex);
  return { link: shareLink("burn", noteId, key, iv), codePromise };
}

export type BurnFileProgress =
  | { phase: "encrypting" }
  | { phase: "uploading" }
  | { phase: "sealing" };

/** Encrypts + uploads a real one-time file drop; returns the one-time link + a short redemption code. */
export async function createBurnFile(
  file: File,
  expiryHours: number,
  onProgress: (p: BurnFileProgress) => void,
): Promise<BurnResult> {
  if (file.size <= 0) throw new Error("That file looks empty.");
  if (file.size > FILE_MAX_BYTES) {
    throw new Error("Too large — Burn Files are capped at 25MB.");
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

  const keyHex = bytesToHex(key);
  const ivHex = bytesToHex(iv);
  // Same as createBurnNote: not awaited, arrives after the "done" state.
  const codePromise = mintCode("file", init.file_id, keyHex, ivHex);
  return { link: shareLink("burnfile", init.file_id, key, iv), codePromise };
}

/** Recipient side: resolves a short redemption code into the same kind of
 * link a sender would share, so the existing app viewer handles the rest —
 * no need to duplicate note/file viewing here. */
export async function redeemCode(code: string): Promise<string> {
  const trimmed = code.trim();
  if (!trimmed) throw new Error("Enter a code first.");

  const res = await fetch(`${SUPABASE_URL}/functions/v1/redeem-code`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
    body: JSON.stringify({ code: trimmed }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error ?? "That code could not be redeemed.");
  }

  const kind = data.target_kind === "file" ? "burnfile" : "burn";
  return `${APP_URL}#/${kind}/${data.target_id}?k=${data.key_hex}&v=${data.iv_hex}`;
}
