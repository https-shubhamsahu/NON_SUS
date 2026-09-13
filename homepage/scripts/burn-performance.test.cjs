// No network calls: exercise the real TypeScript pipeline with native WebCrypto.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText, filename);
};
const crypto = require('../src/lib/burnCrypto.ts');
const api = require('../src/lib/burnApi.ts');
const deferred = () => {
  let resolve;
  const promise = new Promise(r => { resolve = r; });
  return { promise, resolve };
};
const json = (body, status = 200) => new Response(JSON.stringify(body), { status });

test('WebCrypto still matches the existing Dart known-answer vectors', async () => {
  const key = Uint8Array.from({ length: 32 }, (_, i) => i + 1);
  const iv = Uint8Array.from({ length: 16 }, (_, i) => 0xa0 + i);
  assert.equal(await crypto.encryptNote('Meet at the library, 6pm. Burn after reading. äöü✓', key, iv),
    '71lEqc0Io3FpcmZgKYel21XtoAbwGtLrCxvNr7EFoQu+hzjeP+Pg5XjnAWmz6EMr0aCQC+1tPVTKU+TYxjJQ7Q==');
  const packed = crypto.packBurnFilePayload('exam notes.pdf', 'application/pdf', Uint8Array.from({ length: 1000 }, (_, i) => (i * 7 + 3) % 256));
  assert.equal(Buffer.from((await crypto.encryptFilePayload(packed, key, iv)).subarray(0, 48)).toString('base64'),
    'nkE9Mmwi34RhWM7mGECy27W5S6AJaqrkr8Xh57HTSiVE1cWIJMkCME6RxwAvDLKp');
});

test('predicted upload size equals real CBC output; packing stays byte-compatible', async () => {
  const { key, iv } = crypto.generateKeyMaterial();
  for (const name of ['a.txt', '秘密🔒.txt', 'quote"\\.bin']) {
    for (const size of [1, 15, 16, 17, 31, 32, 1024, api.FILE_MAX_BYTES]) {
      const bytes = new Uint8Array(size);
      const packed = crypto.packBurnFilePayload(name, 'application/octet-stream', bytes);
      const header = new TextEncoder().encode(JSON.stringify({ name, type: 'application/octet-stream', size }));
      assert.equal(new DataView(packed.buffer).getUint32(0, false), header.length);
      assert.deepEqual(packed.subarray(4, 4 + header.length), header);
      assert.deepEqual(packed.subarray(4 + header.length), bytes);
      const encrypted = await crypto.encryptFilePayload(packed, key, iv);
      assert.equal(encrypted.length, crypto.burnFileCiphertextSize(name, 'application/octet-stream', size));
    }
  }
});

test('file init overlaps reading, PUT waits for both, confirm waits for PUT', async (t) => {
  const read = deferred(), setup = deferred(), upload = deferred();
  const events = [];
  let declared;
  t.mock.method(globalThis, 'fetch', async (url, options) => {
    if (url.endsWith('/burn-file-init')) {
      events.push('init');
      declared = JSON.parse(options.body).declared_size_bytes;
      await setup.promise;
      return json({ file_id: 'test-id', signed_upload_url: 'https://upload.invalid/file' });
    }
    if (url === 'https://upload.invalid/file') {
      events.push('put');
      assert.equal(options.body.length, declared);
      await upload.promise;
      return new Response(null, { status: 200 });
    }
    if (url.endsWith('/burn-file-confirm')) {
      events.push('confirm');
      return json({ ok: true });
    }
    assert.ok(url.endsWith('/create-redemption-code'));
    return json({}, 503); // Pairing failure must not invalidate the direct link.
  });
  const resultPromise = api.createBurnFile({ name: 'test.txt', size: 3, type: 'text/plain', arrayBuffer: () => read.promise }, 24, () => {});
  assert.deepEqual(events, ['init']); // Reading is still blocked.
  setup.resolve();
  await new Promise(setImmediate);
  assert.deepEqual(events, ['init']); // No premature upload.
  read.resolve(new Uint8Array([1, 2, 3]).buffer);
  while (!events.includes('put')) await new Promise(setImmediate);
  assert.deepEqual(events, ['init', 'put']);
  upload.resolve();
  const result = await resultPromise;
  assert.deepEqual(events, ['init', 'put', 'confirm']);
  assert.match(result.link, /#\/burnfile\/test-id\?k=[a-f0-9]{64}&v=[a-f0-9]{32}$/);
  assert.equal(await result.grantPromise, null);
});

test('notes return a direct link without waiting for pairing', async (t) => {
  const grant = deferred();
  t.mock.method(globalThis, 'fetch', async (url) => {
    if (url.endsWith('/burn_notes')) return new Response(null, { status: 201 });
    await grant.promise;
    return json({}, 503);
  });
  const result = await api.createBurnNote('performance test');
  assert.match(result.link, /#\/burn\//);
  grant.resolve();
  assert.equal(await result.grantPromise, null);
});

for (const failingStage of ['init', 'put', 'confirm']) {
  test(`a failed ${failingStage} never produces a usable share`, async (t) => {
    const events = [];
    t.mock.method(globalThis, 'fetch', async (url) => {
      const stage = url.endsWith('/burn-file-init') ? 'init' : url.endsWith('/burn-file-confirm') ? 'confirm' : 'put';
      events.push(stage);
      if (stage === failingStage) return json({ error: 'test failure' }, 503);
      return json({ file_id: 'test', signed_upload_url: 'https://upload.invalid/file' });
    });
    await assert.rejects(api.createBurnFile(new File(['x'], 'x.txt'), 1, () => {}));
    assert.deepEqual(events, ['init', 'put', 'confirm'].slice(0, ['init', 'put', 'confirm'].indexOf(failingStage) + 1));
  });
}
