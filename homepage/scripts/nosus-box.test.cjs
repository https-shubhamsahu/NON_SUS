/* eslint-disable @typescript-eslint/no-require-imports */
// Sealed box vector. Dart asserts the same hex in test/unit/nosus_box_test.dart.
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

const RECIP = Buffer.from("33".repeat(32), "hex");
const EPH = Buffer.from("44".repeat(32), "hex");
const NONCE = Buffer.from("000102030405060708090a0b", "hex");
const EXPECTED = "01045b36890dacbd7c9a96bb74a1ee28b3d2d75b72e09a20ef25cf8e6fd8a9f0350d0e14bed8d4682a34d83538bdff5b96e89a6666ec0db5745d02fa1210072df75a000102030405060708090a0beae60c25d460db92856999abdafb700c726d34bfaa3544369cf3";

function pub(d) {
  const e = crypto.createECDH("prime256v1");
  e.setPrivateKey(d);
  return new Uint8Array(e.getPublicKey(null, "uncompressed"));
}

test("sealBox matches the pinned vector", async () => {
  const box = await seal.sealBox(pub(RECIP), "drop", new TextEncoder().encode("hello drop"), {
    ephemeral: { privateKey: new Uint8Array(EPH), publicKey: pub(EPH) },
    nonce: new Uint8Array(NONCE),
  });
  assert.equal(Buffer.from(box).toString("hex"), EXPECTED);
});

test("openBox round-trips and rejects the wrong context", async () => {
  const box = new Uint8Array(Buffer.from(EXPECTED, "hex"));
  const plain = await seal.openBox(new Uint8Array(RECIP), pub(RECIP), "drop", box);
  assert.equal(new TextDecoder().decode(plain), "hello drop");
  await assert.rejects(seal.openBox(new Uint8Array(RECIP), pub(RECIP), "group-key:x:1", box));
});

test("sealWithKey round-trips and rejects a flipped byte", async () => {
  const key = new Uint8Array(32).fill(7);
  const aad = new TextEncoder().encode("nosus-group/1");
  const box = await seal.sealWithKey(key, new TextEncoder().encode("hi"), aad);
  assert.equal(new TextDecoder().decode(await seal.openWithKey(key, box, aad)), "hi");
  box[box.length - 1] ^= 1;
  await assert.rejects(seal.openWithKey(key, box, aad));
});
