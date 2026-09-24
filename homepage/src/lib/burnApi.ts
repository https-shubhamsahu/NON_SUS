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
//           the server holds the key/IV until the code is used or expires.
//           Every share here mints one, so the server receives the key even
//           if the sender ends up handing out the direct link. The two digits
//           are paired with an unguessable link token (#/redeem/<token>);
//           that pairing link is what the tool shares when a code exists.
import { APP_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";
import {
  bytesToHex,
  burnFileCiphertextSize,
  encryptFilePayload,
  encryptNote,
  generateKeyMaterial,
  packBurnFilePayload,
} from "./burnCrypto";

export const NOTE_MAX_CHARS = 50000;
// Kept in sync with remote_configs.burn_files_max_size_bytes (server is the
// authoritative enforcement point — this is only the client-side pre-flight
// check, so the browser fails fast instead of encrypting/uploading a file
// the server will reject anyway). The Flutter app additionally supports
// sharing multiple files under one 25MB combined link — this landing-page
// tool is still single-file only.
export const FILE_MAX_BYTES = 25 * 1024 * 1024;

export type RedemptionPairing = {
  code: string;
  /** `#/redeem/<token>`: opens only after the recipient types `code`. */
  link: string;
  /** When the pairing link and code stop working (ISO 8601), if known. */
  expiresAt: string | null;
};
export type BurnResult = {
  /** Direct link: carries the key and IV in the fragment, needs no code. */
  link: string;
  pairingPromise: Promise<RedemptionPairing | null>;
};

// A share should never hang on the code: past this, fall back to the direct link.
const PAIRING_TIMEOUT_MS = 8000;

function shareLink(kind: "burn" | "burnfile", id: string, key: Uint8Array, iv: Uint8Array): string {
  // Key + IV live in the fragment, which browsers never send in a request.
  return `${APP_URL}#/${kind}/${id}?k=${bytesToHex(key)}&v=${bytesToHex(iv)}`;
}

/** The link the sender hands out (QR and Copy Link). With a code it is the
 * pairing link, so the two digits are actually needed to open the drop;
 * without one (minting failed) it is the direct link. */
export function linkToShare(directLink: string, pairing: RedemptionPairing | null): string {
  return pairing ? pairing.link : directLink;
}

/** Redeem tab: turns a pasted pairing link, bare pairing token, or direct
 * burn link into the app URL that opens it. Null for anything else. */
export function appLinkFromPaste(raw: string): string | null {
  const text = raw.trim();
  const token =
    text.match(/[#/]redeem\/([a-f0-9]{64})(?![a-f0-9])/i) ?? text.match(/^([a-f0-9]{64})$/i);
  if (token) return `${APP_URL}#/redeem/${token[1].toLowerCase()}`;
  const direct = text.match(
    /#\/(burn|burnfile)\/([0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12})\?k=([0-9a-f]{64})&v=([0-9a-f]{32})(?![0-9a-f])/i,
  );
  if (direct) {
    const [, kind, id, k, v] = direct;
    return `${APP_URL}#/${kind.toLowerCase()}/${id.toLowerCase()}?k=${k.toLowerCase()}&v=${v.toLowerCase()}`;
  }
  return null;
}

/** Best-effort: mints a two-digit confirmation and its secure pairing link.
 * Never throws — the direct link already works, so a hiccup here should not
 * fail the share. */
async function mintPairing(
  targetKind: "note" | "file",
  targetId: string,
  keyHex: string,
  ivHex: string,
): Promise<RedemptionPairing | null> {
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
      signal: AbortSignal.timeout(PAIRING_TIMEOUT_MS),
    });
    if (!res.ok) return null;
    const data = await res.json();
    if (
      typeof data.code !== "string" ||
      !/^\d{2}$/.test(data.code) ||
      typeof data.redeem_token !== "string" ||
      !/^[a-f0-9]{64}$/.test(data.redeem_token)
    ) {
      return null;
    }
    return {
      code: data.code,
      link: `${APP_URL}#/redeem/${data.redeem_token}`,
      expiresAt: typeof data.expires_at === "string" ? data.expires_at : null,
    };
  } catch {
    return null;
  }
}

/** Creates a real self-destructing note and optional two-digit pairing. */
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
  // Not awaited: READY TO SHARE shows as soon as the ciphertext is stored,
  // and the UI hands out a link once this settles (see linkToShare).
  const pairingPromise = mintPairing("note", noteId, keyHex, ivHex);
  return { link: shareLink("burn", noteId, key, iv), pairingPromise };
}

export type BurnFileProgress =
  | { phase: "encrypting" }
  | { phase: "uploading" }
  | { phase: "sealing" };

/** Encrypts + uploads a real one-time file drop and optional pairing. */
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
  const mimeType = file.type || "application/octet-stream";
  const headers = {
    "Content-Type": "application/json",
    apikey: SUPABASE_ANON_KEY,
  };

  // Overlap file preparation with server setup; observe failures on both branches.
  const [ciphertext, init] = await Promise.all([
    (async () => {
      const packed = packBurnFilePayload(file.name, mimeType, new Uint8Array(await file.arrayBuffer()));
      return encryptFilePayload(packed, key, iv);
    })(),
    (async () => {
      const res = await fetch(`${SUPABASE_URL}/functions/v1/burn-file-init`, {
        method: "POST",
        headers,
        body: JSON.stringify({
          declared_size_bytes: burnFileCiphertextSize(file.name, mimeType, file.size),
          expiry_hours: expiryHours,
        }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Could not start this upload.");
      return data;
    })(),
  ]);

  onProgress({ phase: "uploading" });
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
  const pairingPromise = mintPairing("file", init.file_id, keyHex, ivHex);
  return { link: shareLink("burnfile", init.file_id, key, iv), pairingPromise };
}

/** Recipient side: resolves a short redemption code into the same kind of
 * link a sender would share, so the existing app viewer handles the rest —
 * no need to duplicate note/file viewing here. */
export async function redeemCode(code: string, redeemToken?: string): Promise<string> {
  const trimmed = code.trim();
  if (!trimmed) throw new Error("Enter a code first.");

  const res = await fetch(`${SUPABASE_URL}/functions/v1/redeem-code`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
    body: JSON.stringify({ code: trimmed, ...(redeemToken ? { redeem_token: redeemToken } : {}) }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error ?? "That code could not be redeemed.");
  }

  const kind = data.target_kind === "file" ? "burnfile" : "burn";
  return `${APP_URL}#/${kind}/${data.target_id}?k=${data.key_hex}&v=${data.iv_hex}`;
}
