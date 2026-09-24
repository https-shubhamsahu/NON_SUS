/* eslint-disable @typescript-eslint/no-require-imports -- Node CJS test harness loads TypeScript without another dependency. */
// Runs the real inline shim from src/lib/legacyLinkShim.ts against a fake
// window. The property that matters: Cloudflare Web Analytics must never load
// on, or be left looking at, a URL whose fragment carries key material.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText, filename);
};
const { legacyLinkShim, CLOUDFLARE_BEACON_SRC } = require('../src/lib/legacyLinkShim.ts');

const KEY_LINK = '#/burn/0d9b3c1e-7f0a-4c2e-9a51-3b8f6d2e4a10?k=' + 'a'.repeat(64) + '&v=' + 'b'.repeat(32);

function load(url, token = 'abc123def456') {
  const start = new URL(url);
  const location = {
    hash: start.hash,
    pathname: start.pathname,
    search: start.search,
    hostname: start.hostname,
    replaced: null,
    replace(target) { this.replaced = { target, hashAtExit: this.hash }; },
  };
  const scripts = [];
  const listeners = {};
  const window = {
    location,
    history: {
      replaceState(_state, _title, next) {
        const u = new URL(next, start.origin);
        location.hash = u.hash;
        location.pathname = u.pathname;
        location.search = u.search;
      },
    },
    addEventListener(type, fn) { listeners[type] = fn; },
    document: {
      createElement: () => ({ attrs: {}, setAttribute(k, v) { this.attrs[k] = v; } }),
      head: { appendChild: (el) => scripts.push(el) },
    },
  };
  vm.runInNewContext(legacyLinkShim(token), { window });
  return {
    location,
    scripts,
    changeHash(hash) { location.hash = hash; listeners.hashchange?.(); },
  };
}

test('a legacy burn link forwards to the app with its key and never loads analytics', () => {
  const page = load('https://nosus.foo/' + KEY_LINK);
  assert.equal(page.location.replaced.target, 'https://app.nosus.foo/' + KEY_LINK);
  assert.equal(page.scripts.length, 0);
});

test('path-style legacy links and auth callbacks forward without analytics', () => {
  for (const url of [
    'https://nosus.foo/v/abc123',
    'https://nosus.foo/#access_token=secret&refresh_token=secret',
    'https://nosus.foo/?code=pkce-code',
  ]) {
    const page = load(url);
    assert.ok(page.location.replaced, url);
    assert.equal(page.scripts.length, 0, url);
  }
});

test('an ordinary visit loads the beacon once, with SPA tracking off', () => {
  const page = load('https://nosus.foo/');
  assert.equal(page.location.replaced, null);
  assert.equal(page.scripts.length, 1);
  assert.equal(page.scripts[0].src, CLOUDFLARE_BEACON_SRC);
  assert.equal(page.scripts[0].type, 'module'); // matches Cloudflare's issued snippet
  assert.deepEqual(JSON.parse(page.scripts[0].attrs['data-cf-beacon']), { token: 'abc123def456', spa: false });
});

test('the Go desk does not load analytics', () => {
  const page = load('https://nosus.foo/go');
  assert.equal(page.location.replaced, null);
  assert.equal(page.scripts.length, 0);
});

test('the Drop page and handle subdomains do not load analytics', () => {
  for (const url of [
    'https://nosus.foo/to',
    'https://nosus.foo/to/',
    'https://nosus.foo/to?h=alice',
    'https://nosus.foo/to#alice',
    'https://alice.nosus.foo/',
    'https://ALICE.nosus.foo/',
  ]) {
    const page = load(url);
    assert.equal(page.location.replaced, null, url);
    assert.equal(page.scripts.length, 0, url);
  }
  // The apex and www still count.
  assert.equal(load('https://www.nosus.foo/').scripts.length, 1);
  assert.equal(load('https://nosus.foo/tools').scripts.length, 1);
});

test('plain in-page anchors still count; any other fragment skips analytics', () => {
  assert.equal(load('https://nosus.foo/#features').scripts.length, 1);
  for (const hash of ['#/r/' + 'c'.repeat(32), '#/unknown/route', '#k=' + 'a'.repeat(64), '#features?k=1']) {
    const page = load('https://nosus.foo/' + hash);
    assert.equal(page.scripts.length, 0, hash);
  }
});

test('no token means no beacon, but legacy forwarding still works', () => {
  assert.equal(load('https://nosus.foo/', '').scripts.length, 0);
  assert.ok(load('https://nosus.foo/' + KEY_LINK, '').location.replaced);
});

test('a key link pasted into an open tab is stripped from the URL before forwarding', () => {
  const page = load('https://nosus.foo/');
  assert.equal(page.scripts.length, 1); // the beacon is already running
  page.changeHash(KEY_LINK);
  assert.equal(page.location.replaced.target, 'https://app.nosus.foo/' + KEY_LINK);
  assert.equal(page.location.replaced.hashAtExit, ''); // what the beacon's exit report can see
});

test('an in-page anchor change does not navigate away', () => {
  const page = load('https://nosus.foo/');
  page.changeHash('#faq');
  assert.equal(page.location.replaced, null);
});

test('a token that could break out of the inline script is rejected at build time', () => {
  assert.throws(() => legacyLinkShim('abc"</script><script>alert(1)//'));
});
