// WebCrypto implementation of the app's burn note/file encryption — verified
// byte-for-byte against the Flutter client (package:encrypt) via the
// known-answer vectors in test/unit/burn_crypto_web_compat_test.dart and
// tool/crypto_compat_probe.dart at the repo root. Do NOT change algorithms,
// padding, or packing here without updating those in lockstep.
//
//   Burn Note:  AES-256-CTR (counter = IV, standard full-block increment)
//               over MANUALLY PKCS7-PADDED utf8 plaintext — the `encrypt`
//               package pads even in its default SIC/CTR mode. Ciphertext
//               is base64, stored inline in the burn_notes row.
//   Burn File:  AES-256-CBC (WebCrypto pads PKCS7 natively) over the packed
//               payload `[4-byte BE header len][JSON {name,type,size}][bytes]`.
//               Ciphertext is raw binary, uploaded to Storage.
//
// Keys/IVs travel ONLY in the URL hash fragment (never sent to any server).

const subtle = globalThis.crypto?.subtle;

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(bin);
}

/** Fresh 256-bit key + 128-bit IV from the platform CSPRNG. */
export function generateKeyMaterial(): { key: Uint8Array; iv: Uint8Array } {
  const key = new Uint8Array(32);
  const iv = new Uint8Array(16);
  globalThis.crypto.getRandomValues(key);
  globalThis.crypto.getRandomValues(iv);
  return { key, iv };
}

function pkcs7Pad(data: Uint8Array): Uint8Array {
  const padLen = 16 - (data.length % 16);
  const padded = new Uint8Array(data.length + padLen);
  padded.set(data);
  padded.fill(padLen, data.length);
  return padded;
}

/** Burn Note path: returns base64 ciphertext for the burn_notes row. */
export async function encryptNote(
  plaintext: string,
  key: Uint8Array,
  iv: Uint8Array,
): Promise<string> {
  const cryptoKey = await subtle.importKey(
    "raw",
    key as BufferSource,
    { name: "AES-CTR" },
    false,
    ["encrypt"],
  );
  const padded = pkcs7Pad(new TextEncoder().encode(plaintext));
  const ciphertext = new Uint8Array(
    await subtle.encrypt(
      { name: "AES-CTR", counter: iv as BufferSource, length: 128 },
      cryptoKey,
      padded as BufferSource,
    ),
  );
  return bytesToBase64(ciphertext);
}

/** Mirrors packBurnFilePayload in lib/services/burn_file_crypto.dart. */
export function packBurnFilePayload(
  fileName: string,
  mimeType: string,
  fileBytes: Uint8Array,
): Uint8Array {
  const header = new TextEncoder().encode(
    JSON.stringify({ name: fileName, type: mimeType, size: fileBytes.length }),
  );
  const packed = new Uint8Array(4 + header.length + fileBytes.length);
  new DataView(packed.buffer).setUint32(0, header.length, false);
  packed.set(header, 4);
  packed.set(fileBytes, 4 + header.length);
  return packed;
}

/** Burn File path: returns the raw binary ciphertext for Storage upload. */
export async function encryptFilePayload(
  packed: Uint8Array,
  key: Uint8Array,
  iv: Uint8Array,
): Promise<Uint8Array> {
  const cryptoKey = await subtle.importKey(
    "raw",
    key as BufferSource,
    { name: "AES-CBC" },
    false,
    ["encrypt"],
  );
  return new Uint8Array(
    await subtle.encrypt(
      { name: "AES-CBC", iv: iv as BufferSource },
      cryptoKey,
      packed as BufferSource,
    ),
  );
}
