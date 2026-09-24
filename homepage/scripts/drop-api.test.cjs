/* eslint-disable @typescript-eslint/no-require-imports */
// Drop: handle parsing and the manifest + sealed box round trip.
// The pinned hex values are asserted by Dart too, in
// test/unit/drop_manifest_test.dart.
const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const ts = require("typescript");

// dropApi.ts imports "./nosusSeal" and "./links" without an extension.
require.extensions[".ts"] = (module, filename) => {
  module._compile(
    ts.transpileModule(fs.readFileSync(filename, "utf8"), {
      compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
    }).outputText,
    filename,
  );
};
const Module = require("node:module");
const resolve = Module._resolveFilename;
Module._resolveFilename = function (request, parent, ...rest) {
  if (parent && parent.filename && parent.filename.endsWith(".ts") && request.startsWith("./")) {
    const candidate = path.join(path.dirname(parent.filename), request + ".ts");
    if (fs.existsSync(candidate)) return candidate;
  }
  return resolve.call(this, request, parent, ...rest);
};

const drop = require("../src/lib/dropApi.ts");
const seal = require("../src/lib/nosusSeal.ts");

function pub(d) {
  const e = crypto.createECDH("prime256v1");
  e.setPrivateKey(d);
  return new Uint8Array(e.getPublicKey(null, "uncompressed"));
}

const RECIP = Buffer.from("33".repeat(32), "hex");
const EPH = Buffer.from("44".repeat(32), "hex");
const NONCE = new Uint8Array(Buffer.from("000102030405060708090a0b", "hex"));
const FILE_NONCE = new Uint8Array(Buffer.from("0c0d0e0f1011121314151617", "hex"));
const DROP_ID = "00000000-0000-4000-8000-000000000001";
const FILE_KEY = new Uint8Array(32).fill(0x55);

const MANIFEST_JSON =
  '{"v":1,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"photo.jpg","m":"image/jpeg","s":10,"from":"Asha","note":"hi"}';
const EXPECTED_BOX =
  "01045b36890dacbd7c9a96bb74a1ee28b3d2d75b72e09a20ef25cf8e6fd8a9f0350d0e14bed8d4682a34d83538bdff5b96e89a6666ec0db5745d02fa1210072df75a000102030405060708090a0b0fbfff41753e52536ac4cbb60172d23df558b7026c38fb9edb98606fc133d590c2d3d8c67106060d5e992ab379993a67d563ac5fbe222eee263a903e72645ea439f2b8b76f69f3138726670f01b16e17eefb2c21702eb60895a488b5f19312ea3cc96511d2b9adb4455dd759ba24abb1b6e72180c8dc47a4155d7e3a95eb2648a50449debeccdb523fa5fe";
const EXPECTED_FILE = "0c0d0e0f101112131415161723aa12d9c82504cf54599f9f52b2c0d13d874922f5ee662b6809";
const EXPECTED_CHECK = "1705 0386 8627";

test("handles parse from query, hash, and subdomain", () => {
  assert.equal(drop.parseHandle({ search: "?h=alice" }), "alice");
  assert.equal(drop.parseHandle({ search: "?h=Alice-9" }), "alice-9");
  assert.equal(drop.parseHandle({ search: "?h=%40alice" }), "alice");
  assert.equal(drop.parseHandle({ hash: "#alice" }), "alice");
  assert.equal(drop.parseHandle({ hash: "#/alice" }), "alice");
  assert.equal(drop.parseHandle({ hostname: "alice.nosus.foo" }), "alice");
  assert.equal(drop.parseHandle({ hostname: "Alice.NOSUS.foo" }), "alice");
  // Query wins over the subdomain.
  assert.equal(drop.parseHandle({ search: "?h=bobby", hostname: "alice.nosus.foo" }), "bobby");
});

test("reserved and malformed handles are refused", () => {
  for (const bad of ["app", "www", "go", "to", "admin", "no-sus", "settings", "abc", "a".repeat(21), "-abc", "abc-", "ab--cd", "xn--abc", "al_ce", "al ce", "é-name"]) {
    assert.equal(drop.validHandle(bad), false, bad);
    assert.equal(drop.parseHandle({ search: `?h=${encodeURIComponent(bad)}` }), null, bad);
  }
  assert.equal(drop.parseHandle({ hostname: "app.nosus.foo" }), null);
  assert.equal(drop.parseHandle({ hostname: "www.nosus.foo" }), null);
  assert.equal(drop.parseHandle({ hostname: "nosus.foo" }), null);
  assert.equal(drop.parseHandle({ hostname: "alice.evil.com" }), null);
  assert.equal(drop.parseHandle({ hostname: "a.b.nosus.foo" }), null);
  assert.equal(drop.parseHandle({}), null);
  for (const good of ["abcd", "a".repeat(20), "al-ce", "0000"]) assert.equal(drop.validHandle(good), true, good);
});

test("manifest is built, capped, and parsed back", () => {
  const m = drop.buildManifest({
    fileKey: FILE_KEY,
    name: "photo.jpg",
    mime: "image/jpeg",
    size: 10,
    from: " Asha ",
    note: "hi",
  });
  assert.equal(JSON.stringify(m), MANIFEST_JSON);
  const long = drop.buildManifest({ fileKey: FILE_KEY, name: "n".repeat(500), mime: "", size: 1, from: "x".repeat(99), note: "😀".repeat(400) });
  assert.equal(long.n.length, drop.NAME_MAX);
  assert.equal(long.from.length, drop.FROM_MAX);
  assert.equal(Array.from(long.note).length, drop.NOTE_MAX);
  assert.equal(long.m, "application/octet-stream");
  assert.throws(() => drop.buildManifest({ fileKey: FILE_KEY, name: "a", mime: "", size: 1, from: "  ", note: "" }));
  assert.deepEqual(drop.parseManifest(new TextEncoder().encode(MANIFEST_JSON)), m);
  for (const bad of [
    '{"v":2,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"a","m":"","s":1,"from":"x","note":""}',
    '{"v":1,"k":"AAAA","n":"a","m":"","s":1,"from":"x","note":""}',
    '{"v":1,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"","m":"","s":1,"from":"x","note":""}',
    '{"v":1,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"a","m":"","s":-1,"from":"x","note":""}',
    '{"v":1,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"a","m":"","s":1,"from":"","note":""}',
    "[]",
  ]) {
    assert.throws(() => drop.parseManifest(new TextEncoder().encode(bad)), bad);
  }
});

test("manifest box matches the pinned vector and opens only under its drop id", async () => {
  const box = await seal.sealBox(pub(RECIP), drop.dropContext(DROP_ID), new TextEncoder().encode(MANIFEST_JSON), {
    ephemeral: { privateKey: new Uint8Array(EPH), publicKey: pub(EPH) },
    nonce: NONCE,
  });
  if (process.env.PRINT_VECTORS) console.log("BOX", Buffer.from(box).toString("hex"));
  else assert.equal(Buffer.from(box).toString("hex"), EXPECTED_BOX);
  const plain = await seal.openBox(new Uint8Array(RECIP), pub(RECIP), drop.dropContext(DROP_ID), box);
  assert.equal(drop.parseManifest(plain).from, "Asha");
  await assert.rejects(seal.openBox(new Uint8Array(RECIP), pub(RECIP), drop.dropContext("00000000-0000-4000-8000-000000000002"), box));
});

test("sealEnvelopes seals one box per device, each openable by its key", async () => {
  const other = Buffer.from("66".repeat(32), "hex");
  const devices = drop.parseDevices([
    { id: "11111111-1111-4111-8111-111111111111", publicKey: seal.b64url(pub(RECIP)) },
    { id: "22222222-2222-4222-8222-222222222222", publicKey: seal.b64url(pub(other)) },
    { id: "not-a-uuid", publicKey: seal.b64url(pub(other)) },
    { id: "33333333-3333-4333-8333-333333333333", publicKey: "short" },
  ]);
  assert.equal(devices.length, 2);
  const manifest = drop.parseManifest(new TextEncoder().encode(MANIFEST_JSON));
  const envelopes = await drop.sealEnvelopes(devices, DROP_ID, manifest);
  assert.equal(envelopes.length, 2);
  for (const [i, priv] of [RECIP, other].entries()) {
    assert.match(envelopes[i].box, /^[A-Za-z0-9_-]{128,8192}$/);
    const plain = await seal.openBox(new Uint8Array(priv), pub(priv), drop.dropContext(DROP_ID), seal.b64urlDecode(envelopes[i].box));
    assert.deepEqual(drop.parseManifest(plain), manifest);
  }
});

test("file ciphertext is bound to its drop id", async () => {
  const plain = new TextEncoder().encode("file bytes");
  const box = await seal.sealWithKey(FILE_KEY, plain, drop.dropFileAad(DROP_ID), FILE_NONCE);
  assert.equal(box.length, plain.length + 28);
  if (process.env.PRINT_VECTORS) console.log("FILE", Buffer.from(box).toString("hex"));
  else assert.equal(Buffer.from(box).toString("hex"), EXPECTED_FILE);
  assert.equal(new TextDecoder().decode(await seal.openWithKey(FILE_KEY, box, drop.dropFileAad(DROP_ID))), "file bytes");
  await assert.rejects(seal.openWithKey(FILE_KEY, box, drop.dropFileAad("00000000-0000-4000-8000-000000000002")));
});

test("door check code matches the Dart safetyCode", async () => {
  const code = await drop.safetyCode([pub(EPH), pub(RECIP)]);
  assert.equal(code, await drop.safetyCode([pub(RECIP), pub(EPH)]));
  assert.match(code, /^\d{4} \d{4} \d{4}$/);
  if (process.env.PRINT_VECTORS) console.log("CHECK", code);
  else assert.equal(code, EXPECTED_CHECK);
});
