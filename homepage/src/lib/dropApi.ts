// Drop: a visitor sends one file to a NO SUS address.
//
// The browser picks a random 32-byte file key, seals the file with it
// (sealWithKey, aad "nosus-drop-file/1:<drop id>"), and seals a small JSON
// manifest {v,k,n,m,s,from,note} to each of the owner's device keys
// (sealBox, context "drop:<drop id>"). The server gets ciphertext, its
// size, timing, and an HMAC of the sender's IP. The file name, sender
// name, and note are inside the sealed manifest.
//
// The server hands out the device keys, so it could hand out its own. The
// door check code (safetyCode) is the same 12 digits the owner sees on
// their phone; matching codes mean the keys were not swapped.
//
// Mirrors lib/features/address/drop/drop_manifest.dart. Tested in
// scripts/drop-api.test.cjs.

import { b64url, b64urlDecode, randomBytes, sealBox, sealWithKey } from "./nosusSeal";
import { SUPABASE_ANON_KEY, SUPABASE_URL } from "./links";

export const DROP_MAX_BYTES = 25 * 1024 * 1024;
export const FROM_MAX = 40;
export const NOTE_MAX = 280;
export const NAME_MAX = 200;

// Keep in step with address_handle_valid() in
// supabase/migrations/20260924110000_nosus_drop.sql.
export const RESERVED_HANDLES = new Set([
  "app", "www", "api", "go", "to", "admin", "support", "help", "mail",
  "nosus", "no-sus", "root", "static", "assets", "burn", "redeem", "join",
  "status", "blog", "docs", "login", "signup", "settings",
]);

const HANDLE_RE = /^[a-z0-9](?:[a-z0-9-]{2,18}[a-z0-9])$/;

export function validHandle(value: string): boolean {
  return HANDLE_RE.test(value) && !value.includes("--") && !RESERVED_HANDLES.has(value);
}

function clean(value: string | null | undefined): string | null {
  if (!value) return null;
  let v = value.trim().toLowerCase();
  try {
    v = decodeURIComponent(v);
  } catch {
    return null;
  }
  v = v.replace(/^@/, "");
  return validHandle(v) ? v : null;
}

/** Handle from `?h=`, then `#handle`, then `<handle>.nosus.foo`. */
export function parseHandle(loc: { search?: string; hash?: string; hostname?: string }): string | null {
  const query = new URLSearchParams(loc.search ?? "").get("h");
  if (query != null) return clean(query);
  const hash = (loc.hash ?? "").replace(/^#\/?/, "");
  if (hash) return clean(hash);
  const host = (loc.hostname ?? "").toLowerCase();
  const sub = host.match(/^([^.]+)\.nosus\.foo$/);
  if (sub) return clean(sub[1]);
  return null;
}

export type DropManifest = {
  v: 1;
  k: string;
  n: string;
  m: string;
  s: number;
  from: string;
  note: string;
};

export function dropContext(dropId: string): string {
  return `drop:${dropId}`;
}

export function dropFileAad(dropId: string): Uint8Array {
  return new TextEncoder().encode(`nosus-drop-file/1:${dropId}`);
}

function cut(value: string, max: number): string {
  // Cut by code point so a surrogate pair is never split.
  return Array.from(value.trim()).slice(0, max).join("");
}

export function buildManifest(input: {
  fileKey: Uint8Array;
  name: string;
  mime: string;
  size: number;
  from: string;
  note: string;
}): DropManifest {
  if (input.fileKey.length !== 32) throw new Error("file key");
  const from = cut(input.from, FROM_MAX);
  if (!from) throw new Error("Add your name.");
  return {
    v: 1,
    k: b64url(input.fileKey),
    n: cut(input.name, NAME_MAX) || "file",
    m: cut(input.mime || "application/octet-stream", 100),
    s: input.size,
    from,
    note: cut(input.note, NOTE_MAX),
  };
}

/** Throws on anything that is not a well-formed v1 manifest. */
export function parseManifest(plain: Uint8Array): DropManifest {
  const raw: unknown = JSON.parse(new TextDecoder().decode(plain));
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error("manifest");
  const m = raw as Record<string, unknown>;
  if (m.v !== 1) throw new Error("manifest version");
  if (typeof m.k !== "string" || b64urlDecode(m.k).length !== 32) throw new Error("manifest key");
  if (typeof m.n !== "string" || !m.n || Array.from(m.n).length > NAME_MAX) throw new Error("manifest name");
  if (typeof m.m !== "string" || m.m.length > 100) throw new Error("manifest type");
  if (typeof m.s !== "number" || !Number.isSafeInteger(m.s) || m.s < 0 || m.s > DROP_MAX_BYTES * 2) {
    throw new Error("manifest size");
  }
  if (typeof m.from !== "string" || !m.from || Array.from(m.from).length > FROM_MAX) throw new Error("manifest from");
  const note = m.note ?? "";
  if (typeof note !== "string" || Array.from(note).length > NOTE_MAX) throw new Error("manifest note");
  return { v: 1, k: m.k, n: m.n, m: m.m, s: m.s, from: m.from, note };
}

export type DropDevice = { id: string; publicKey: Uint8Array };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export function parseDevices(raw: unknown): DropDevice[] {
  if (!Array.isArray(raw)) return [];
  const out: DropDevice[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const d = item as Record<string, unknown>;
    if (typeof d.id !== "string" || !UUID.test(d.id) || typeof d.publicKey !== "string") continue;
    if (!/^[A-Za-z0-9_-]{87}$/.test(d.publicKey)) continue;
    const pk = b64urlDecode(d.publicKey);
    if (pk.length !== 65 || pk[0] !== 0x04) continue;
    out.push({ id: d.id, publicKey: pk });
  }
  return out.slice(0, 10);
}

export async function sealEnvelopes(
  devices: DropDevice[],
  dropId: string,
  manifest: DropManifest,
): Promise<{ deviceKeyId: string; box: string }[]> {
  const plain = new TextEncoder().encode(JSON.stringify(manifest));
  const out = [];
  for (const device of devices) {
    const box = await sealBox(device.publicKey, dropContext(dropId), plain);
    out.push({ deviceKeyId: device.id, box: b64url(box) });
  }
  return out;
}

/** 12 digits over the sorted public keys. Same as safetyCode() in
 * lib/core/crypto/nosus_seal.dart. */
export async function safetyCode(publicKeys: Uint8Array[]): Promise<string> {
  const sorted = publicKeys.map(b64url).sort();
  const data = new TextEncoder().encode(`nosus-safety/1:${sorted.join(".")}`);
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", data));
  let n = BigInt(0);
  for (const b of digest.subarray(0, 8)) n = (n << BigInt(8)) | BigInt(b);
  const digits = (n % BigInt("1000000000000")).toString().padStart(12, "0");
  return `${digits.slice(0, 4)} ${digits.slice(4, 8)} ${digits.slice(8)}`;
}

// ── Network ────────────────────────────────────────────────────────────────

async function post(path: string, body: unknown): Promise<{ ok: boolean; status: number; data: Record<string, unknown> }> {
  const res = await fetch(`${SUPABASE_URL}/functions/v1/${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: SUPABASE_ANON_KEY },
    body: JSON.stringify(body),
    referrerPolicy: "no-referrer",
  });
  const data = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  return { ok: res.ok, status: res.status, data };
}

export type DoorState = { open: boolean; needsCode: boolean; devices: DropDevice[]; check: string | null };

export async function getDoor(handle: string): Promise<DoorState> {
  const res = await post("drop-door", { handle });
  if (!res.ok) throw new Error(typeof res.data.error === "string" ? res.data.error : "Could not reach this address.");
  const devices = parseDevices(res.data.devices);
  const open = res.data.open === true && devices.length > 0;
  return {
    open,
    needsCode: res.data.needsCode === true,
    devices,
    check: open ? await safetyCode(devices.map((d) => d.publicKey)) : null,
  };
}

export type SendPhase = "sealing" | "uploading" | "finishing";

export class DropError extends Error {
  constructor(message: string, readonly code: "closed" | "code" | "other") {
    super(message);
  }
}

function sameDevices(a: DropDevice[], b: DropDevice[]): boolean {
  const key = (list: DropDevice[]) => list.map((d) => `${d.id}:${b64url(d.publicKey)}`).sort().join(",");
  return key(a) === key(b);
}

export async function sendDrop(input: {
  handle: string;
  code: string;
  file: File;
  from: string;
  note: string;
  shown: DropDevice[];
  onPhase: (phase: SendPhase) => void;
}): Promise<void> {
  const { file } = input;
  if (file.size <= 0) throw new DropError("That file is empty.", "other");
  if (file.size > DROP_MAX_BYTES) throw new DropError("That file is over 25 MB.", "other");
  const fileKey = randomBytes(32);
  const manifest = buildManifest({
    fileKey,
    name: file.name,
    mime: file.type,
    size: file.size,
    from: input.from,
    note: input.note,
  });

  const init = await post("drop-init", {
    handle: input.handle,
    code: input.code || undefined,
    size: file.size + 28,
  });
  if (!init.ok) {
    const message = typeof init.data.error === "string" ? init.data.error : "Could not start the upload.";
    throw new DropError(message, init.status === 403 ? "code" : init.status === 404 ? "closed" : "other");
  }
  const dropId = typeof init.data.dropId === "string" ? init.data.dropId : "";
  const uploadUrl = typeof init.data.uploadUrl === "string" ? init.data.uploadUrl : "";
  const devices = parseDevices(init.data.devices);
  if (!UUID.test(dropId) || !uploadUrl || devices.length === 0) {
    throw new DropError("Could not start the upload.", "other");
  }
  if (!sameDevices(devices, input.shown)) {
    throw new DropError("Their devices just changed, so the door check changed too. Reload and check it again.", "other");
  }

  input.onPhase("sealing");
  const plain = new Uint8Array(await file.arrayBuffer());
  const box = await sealWithKey(fileKey, plain, dropFileAad(dropId));
  const envelopes = await sealEnvelopes(devices, dropId, manifest);

  input.onPhase("uploading");
  const put = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": "application/octet-stream" },
    body: box.buffer.slice(box.byteOffset, box.byteOffset + box.byteLength) as ArrayBuffer,
    referrerPolicy: "no-referrer",
  });
  if (!put.ok) throw new DropError("The upload failed. Try again.", "other");

  input.onPhase("finishing");
  const confirm = await post("drop-confirm", { dropId, envelopes });
  if (!confirm.ok) {
    throw new DropError(typeof confirm.data.error === "string" ? confirm.data.error : "Could not finish.", "other");
  }
}
