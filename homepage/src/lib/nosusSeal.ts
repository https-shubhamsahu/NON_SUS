// Saved/Go session crypto. Byte layout is locked to lib/core/crypto/nosus_seal.dart.
// Z = ECDH P-256 X, 32 bytes. HKDF-SHA256(salt=sid, info="nosus-go/1"‖dpk‖ppk, L=66)
// → k_pd ‖ k_dp ‖ match. Match code = uint16(match) mod 100.
// AES-256-GCM nonce = direction uint32 BE ‖ seq uint64 BE.
// AAD = utf8("nosus-go/1") ‖ sid ‖ direction byte ‖ seq uint64 BE.
// Direction 1 phone→desk uses k_pd. Direction 2 desk→phone uses k_dp.

export type GoKeyPair = { privateKey: Uint8Array; publicKey: Uint8Array };
export type GoKeyMaterial = { kPd: Uint8Array; kDp: Uint8Array; matchCode: number };

const INFO = new TextEncoder().encode("nosus-go/1");

export function b64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

export function b64urlDecode(value: string): Uint8Array {
  const pad = value.length % 4 === 0 ? "" : "=".repeat(4 - (value.length % 4));
  const bin = atob(value.replace(/-/g, "+").replace(/_/g, "/") + pad);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function randomBytes(length: number): Uint8Array {
  const out = new Uint8Array(length);
  crypto.getRandomValues(out);
  return out;
}

async function importPrivate(privateKey: Uint8Array, publicKey: Uint8Array): Promise<CryptoKey> {
  if (publicKey.length !== 65 || publicKey[0] !== 0x04) throw new Error("public key");
  return crypto.subtle.importKey(
    "jwk",
    {
      kty: "EC",
      crv: "P-256",
      d: b64url(privateKey),
      x: b64url(publicKey.subarray(1, 33)),
      y: b64url(publicKey.subarray(33)),
      ext: true,
    },
    { name: "ECDH", namedCurve: "P-256" },
    true,
    ["deriveBits"],
  );
}

async function importPublic(publicKey: Uint8Array): Promise<CryptoKey> {
  if (publicKey.length !== 65 || publicKey[0] !== 0x04) throw new Error("public key");
  return crypto.subtle.importKey(
    "raw",
    publicKey.buffer.slice(publicKey.byteOffset, publicKey.byteOffset + publicKey.byteLength) as ArrayBuffer,
    { name: "ECDH", namedCurve: "P-256" },
    true,
    [],
  );
}

export async function generateGoKeyPair(): Promise<GoKeyPair> {
  const pair = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const raw = new Uint8Array(await crypto.subtle.exportKey("raw", pair.publicKey));
  const jwk = await crypto.subtle.exportKey("jwk", pair.privateKey);
  if (!jwk.d) throw new Error("private key");
  return { privateKey: b64urlDecode(jwk.d), publicKey: raw };
}

export async function sharedSecret(privateKey: Uint8Array, myPublic: Uint8Array, theirPublic: Uint8Array): Promise<Uint8Array> {
  const mine = await importPrivate(privateKey, myPublic);
  const theirs = await importPublic(theirPublic);
  const bits = await crypto.subtle.deriveBits({ name: "ECDH", public: theirs }, mine, 256);
  return new Uint8Array(bits);
}

export async function hkdfSha256(ikm: Uint8Array, salt: Uint8Array, info: Uint8Array, length: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", ikm.buffer.slice(ikm.byteOffset, ikm.byteOffset + ikm.byteLength) as ArrayBuffer, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    {
      name: "HKDF",
      hash: "SHA-256",
      salt: salt.buffer.slice(salt.byteOffset, salt.byteOffset + salt.byteLength) as ArrayBuffer,
      info: info.buffer.slice(info.byteOffset, info.byteOffset + info.byteLength) as ArrayBuffer,
    },
    key,
    length * 8,
  );
  return new Uint8Array(bits);
}

export async function deriveGoKeys(z: Uint8Array, sid: Uint8Array, dpk: Uint8Array, ppk: Uint8Array): Promise<GoKeyMaterial> {
  if (z.length !== 32 || sid.length !== 16) throw new Error("key input");
  const info = new Uint8Array(INFO.length + dpk.length + ppk.length);
  info.set(INFO, 0);
  info.set(dpk, INFO.length);
  info.set(ppk, INFO.length + dpk.length);
  const okm = await hkdfSha256(z, sid, info, 66);
  const match = ((okm[64] << 8) | okm[65]) % 100;
  return { kPd: okm.slice(0, 32), kDp: okm.slice(32, 64), matchCode: match };
}

export function goNonce(direction: number, seq: number): Uint8Array {
  const nonce = new Uint8Array(12);
  const view = new DataView(nonce.buffer);
  view.setUint32(0, direction);
  view.setUint32(4, Math.floor(seq / 0x100000000));
  view.setUint32(8, seq >>> 0);
  return nonce;
}

export function goAad(sid: Uint8Array, direction: number, seq: number): Uint8Array {
  const out = new Uint8Array(INFO.length + sid.length + 1 + 8);
  out.set(INFO, 0);
  out.set(sid, INFO.length);
  out[INFO.length + sid.length] = direction & 0xff;
  const view = new DataView(out.buffer);
  view.setUint32(out.length - 8, Math.floor(seq / 0x100000000));
  view.setUint32(out.length - 4, seq >>> 0);
  return out;
}

async function gcm(encrypting: boolean, key: Uint8Array, nonce: Uint8Array, data: Uint8Array, aad: Uint8Array): Promise<Uint8Array> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key.buffer.slice(key.byteOffset, key.byteOffset + key.byteLength) as ArrayBuffer,
    "AES-GCM",
    false,
    [encrypting ? "encrypt" : "decrypt"],
  );
  const params = {
    name: "AES-GCM",
    iv: nonce.buffer.slice(nonce.byteOffset, nonce.byteOffset + nonce.byteLength) as ArrayBuffer,
    additionalData: aad.buffer.slice(aad.byteOffset, aad.byteOffset + aad.byteLength) as ArrayBuffer,
    tagLength: 128,
  };
  const buf = encrypting
    ? await crypto.subtle.encrypt(params, cryptoKey, data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer)
    : await crypto.subtle.decrypt(params, cryptoKey, data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength) as ArrayBuffer);
  return new Uint8Array(buf);
}

export async function sealBytes(key: Uint8Array, nonce: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
  const aad = new TextEncoder().encode("nosus-go-file");
  return gcm(true, key, nonce, data, aad);
}

export async function openBytes(key: Uint8Array, nonce: Uint8Array, box: Uint8Array): Promise<Uint8Array> {
  const aad = new TextEncoder().encode("nosus-go-file");
  return gcm(false, key, nonce, box, aad);
}

export async function sealJson(key: Uint8Array, sid: Uint8Array, direction: number, seq: number, event: Record<string, unknown>): Promise<Uint8Array> {
  return gcm(true, key, goNonce(direction, seq), new TextEncoder().encode(JSON.stringify(event)), goAad(sid, direction, seq));
}

export async function openJson(key: Uint8Array, sid: Uint8Array, direction: number, seq: number, box: Uint8Array): Promise<Record<string, unknown>> {
  const plain = await gcm(false, key, goNonce(direction, seq), box, goAad(sid, direction, seq));
  const decoded: unknown = JSON.parse(new TextDecoder().decode(plain));
  if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) throw new Error("event");
  return decoded as Record<string, unknown>;
}
