/* eslint-disable @typescript-eslint/no-require-imports */
// Nosus Go seal: the TypeScript implementation must match Node's own ECDH,
// HKDF, and AES-GCM. Dart asserts the same hex in test/unit/nosus_seal_test.dart.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const crypto = require("node:crypto");
const ts = require("typescript");

require.extensions[".ts"] = (module, filename) => {
  module._compile(
    ts.transpileModule(fs.readFileSync(filename, "utf8"), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    }).outputText,
    filename,
  );
};

const seal = require("../src/lib/nosusSeal.ts");

const SID = Buffer.from("00112233445566778899aabbccddeeff", "hex");
const DESK_PRIV = Buffer.from("11".repeat(32), "hex");
const PHONE_PRIV = Buffer.from("22".repeat(32), "hex");

function uncompressed(privateKey) {
  const ecdh = crypto.createECDH("prime256v1");
  ecdh.setPrivateKey(privateKey);
  return ecdh.getPublicKey(null, "uncompressed");
}

function shared(privateKey, theirPublic) {
  const ecdh = crypto.createECDH("prime256v1");
  ecdh.setPrivateKey(privateKey);
  const z = ecdh.computeSecret(theirPublic);
  return Buffer.concat([Buffer.alloc(32 - z.length), z]);
}

const INFO = Buffer.from("nosus-go/1");

function aad(sid, direction, seq) {
  const out = Buffer.alloc(INFO.length + sid.length + 1 + 8);
  INFO.copy(out, 0);
  sid.copy(out, INFO.length);
  out[INFO.length + sid.length] = direction;
  out.writeUInt32BE(Math.floor(seq / 0x100000000), out.length - 8);
  out.writeUInt32BE(seq >>> 0, out.length - 4);
  return out;
}

function nonce(direction, seq) {
  const out = Buffer.alloc(12);
  out.writeUInt32BE(direction, 0);
  out.writeUInt32BE(Math.floor(seq / 0x100000000), 4);
  out.writeUInt32BE(seq >>> 0, 8);
  return out;
}

test("typescript seal matches node crypto, including a leading-zero shared secret", async () => {
  const dpk = uncompressed(DESK_PRIV);
  const ppk = uncompressed(PHONE_PRIV);
  const z = shared(DESK_PRIV, ppk);
  const zOther = shared(PHONE_PRIV, dpk);
  assert.deepEqual(z, zOther);

  const info = Buffer.concat([Buffer.from("nosus-go/1"), dpk, ppk]);
  const okm = Buffer.from(crypto.hkdfSync("sha256", z, SID, info, 66));
  const match = ((okm[64] << 8) | okm[65]) % 100;

  const derived = await seal.deriveGoKeys(z, SID, dpk, ppk);
  assert.equal(Buffer.from(derived.kPd).toString("hex"), okm.subarray(0, 32).toString("hex"));
  assert.equal(Buffer.from(derived.kDp).toString("hex"), okm.subarray(32, 64).toString("hex"));
  assert.equal(derived.matchCode, match);

  const event = { t: "ack" };
  const box = await seal.sealJson(derived.kPd, SID, 1, 1, event);
  const tsAad = Buffer.from(seal.goAad(SID, 1, 1));
  const nodeAad = aad(SID, 1, 1);
  assert.equal(tsAad.toString("hex"), nodeAad.toString("hex"));
  assert.equal(Buffer.from(seal.goNonce(1, 1)).toString("hex"), nonce(1, 1).toString("hex"));
  const decipher = crypto.createDecipheriv("aes-256-gcm", okm.subarray(0, 32), nonce(1, 1));
  decipher.setAAD(aad(SID, 1, 1));
  decipher.setAuthTag(Buffer.from(box).subarray(box.length - 16));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(box).subarray(0, box.length - 16)),
    decipher.final(),
  ]);
  assert.equal(plain.toString(), JSON.stringify(event));

  const opened = await seal.openJson(derived.kPd, SID, 1, 1, box);
  assert.deepEqual(opened, event);

  const tampered = new Uint8Array(box);
  tampered[0] ^= 0xff;
  await assert.rejects(() => seal.openJson(derived.kPd, SID, 1, 1, tampered));
  await assert.rejects(() => seal.openJson(derived.kDp, SID, 1, 1, box));

  // Search a private scalar whose shared secret starts with 0x00 so padding is tested.
  let zeroPriv = null;
  let zeroZ = null;
  for (let i = 1; i < 4000; i++) {
    const candidate = Buffer.alloc(32);
    candidate.writeUInt32BE(i, 28);
    try {
      const secret = shared(candidate, dpk);
      if (secret[0] === 0) {
        zeroPriv = candidate;
        zeroZ = secret;
        break;
      }
    } catch {
      // scalar out of range
    }
  }
  assert.ok(zeroPriv && zeroZ && zeroZ[0] === 0);
  const fromTs = await seal.sharedSecret(zeroPriv, uncompressed(zeroPriv), dpk);
  assert.equal(Buffer.from(fromTs).toString("hex"), zeroZ.toString("hex"));

  // Printed once so the Dart test can pin the same bytes. Harmless if it stays.
  if (process.env.PRINT_GO_VECTORS) {
    console.log(JSON.stringify({
      sid: SID.toString("hex"),
      deskPriv: DESK_PRIV.toString("hex"),
      phonePriv: PHONE_PRIV.toString("hex"),
      dpk: dpk.toString("hex"),
      ppk: ppk.toString("hex"),
      z: z.toString("hex"),
      okm: okm.toString("hex"),
      box: Buffer.from(box).toString("hex"),
      zeroPriv: zeroPriv.toString("hex"),
      zeroPub: uncompressed(zeroPriv).toString("hex"),
      zeroZ: zeroZ.toString("hex"),
    }));
  }
});
