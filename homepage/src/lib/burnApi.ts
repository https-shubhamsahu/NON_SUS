import { APP_URL, SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";
import {
  bytesToHex,
  burnFileCiphertextSize,
  encryptFilePayload,
  encryptNote,
  generateKeyMaterial,
  packBurnFilePayload,
} from "./burnCrypto";

const subtle = globalThis.crypto.subtle;

export const NOTE_MAX_CHARS = 10000;
export const FILE_MAX_BYTES = 25 * 1024 * 1024;

export type RedeemGrant = { claimToken: string; pin: string; claimUrl: string };
export type BurnResult = { link: string; grantPromise: Promise<RedeemGrant | null> };

const PIN_HASH_PREFIX = "no-sus:redemption:pin:v1:";
const WRAP_KEY_PREFIX = "no-sus:redemption:wrap:v1:";

function shareLink(kind: "burn" | "burnfile", id: string, key: Uint8Array, iv: Uint8Array): string {
  return `${APP_URL}#/${kind}/${id}?k=${bytesToHex(key)}&v=${bytesToHex(iv)}`;
}

function claimUrl(token: string): string {
  return `${APP_URL}#/r/${token}`;
}

async function mintGrant(
  targetKind: "note" | "file",
  targetId: string,
  keyHex: string,
  ivHex: string,
): Promise<RedeemGrant | null> {
  try {
    const tokenBytes = new Uint8Array(16);
    const pinBytes = new Uint8Array(1);
    const wrappingIv = new Uint8Array(16);
    globalThis.crypto.getRandomValues(tokenBytes);
    globalThis.crypto.getRandomValues(pinBytes);
    globalThis.crypto.getRandomValues(wrappingIv);
    const token = bytesToHex(tokenBytes);
    const pin = (pinBytes[0] % 100).toString().padStart(2, "0");
    const encode = (value: string) => new TextEncoder().encode(value);
    const hash = async (value: string) => bytesToHex(new Uint8Array(await subtle.digest("SHA-256", encode(value))));
    const wrappingKey = await subtle.importKey(
      "raw",
      new Uint8Array(await subtle.digest("SHA-256", encode(`${WRAP_KEY_PREFIX}${token}:${pin}`))) as BufferSource,
      { name: "AES-CBC" },
      false,
      ["encrypt"],
    );
    const encryptedMaterial = new Uint8Array(await subtle.encrypt(
      { name: "AES-CBC", iv: wrappingIv as BufferSource },
      wrappingKey,
      encode(JSON.stringify({ key_hex: keyHex, iv_hex: ivHex })) as BufferSource,
    ));
    const res = await fetch(`${SUPABASE_URL}/functions/v1/create-redemption-code`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
      body: JSON.stringify({
          target_kind: targetKind,
          target_id: targetId,
          token_hash: await hash(token),
          pin_hash: await hash(`${PIN_HASH_PREFIX}${token}:${pin}`),
          key_material_ciphertext: bytesToHex(encryptedMaterial),
          key_material_iv_hex: bytesToHex(wrappingIv),
      }),
    });
    if (!res.ok) return null;
    return {
      claimToken: token,
      pin,
      claimUrl: claimUrl(token),
    };
  } catch {
    return null;
  }
}

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
  return {
    link: shareLink("burn", noteId, key, iv),
    grantPromise: mintGrant("note", noteId, keyHex, ivHex),
  };
}

export type BurnFileProgress =
  | { phase: "encrypting" }
  | { phase: "uploading" }
  | { phase: "sealing" };

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
  return {
    link: shareLink("burnfile", init.file_id, key, iv),
    grantPromise: mintGrant("file", init.file_id, keyHex, ivHex),
  };
}

export async function redeemWithPin(claimToken: string, pin: string): Promise<string> {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/redeem-code`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
    body: JSON.stringify({ token: claimToken, pin }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.error ?? "That code could not be redeemed.");
  }
  const kind = data.target_kind === "file" ? "burnfile" : "burn";
  let keyHex = data.key_hex;
  let ivHex = data.iv_hex;
  if (typeof data.key_material_ciphertext === "string" && typeof data.key_material_iv_hex === "string") {
    const decodeHex = (hex: string) => {
      const bytes = new Uint8Array(hex.length / 2);
      for (let i = 0; i < bytes.length; i++) {
        bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
      }
      return bytes;
    };
    const encode = (value: string) => new TextEncoder().encode(value);
    const wrappingKey = await subtle.importKey(
      "raw",
      await subtle.digest("SHA-256", encode(`${WRAP_KEY_PREFIX}${claimToken}:${pin}`)),
      { name: "AES-CBC" },
      false,
      ["decrypt"],
    );
    const plaintext = await subtle.decrypt(
      { name: "AES-CBC", iv: decodeHex(data.key_material_iv_hex) },
      wrappingKey,
      decodeHex(data.key_material_ciphertext),
    );
    const material = JSON.parse(new TextDecoder().decode(plaintext)) as { key_hex?: string; iv_hex?: string };
    keyHex = material.key_hex;
    ivHex = material.iv_hex;
  }
  if (typeof keyHex !== "string" || typeof ivHex !== "string") {
    throw new Error("That pairing could not be opened.");
  }
  return `${APP_URL}#/${kind}/${data.target_id}?k=${keyHex}&v=${ivHex}`;
}

/** Legacy 8-character codes still in the wild. */
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
