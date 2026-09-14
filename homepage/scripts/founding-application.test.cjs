/* eslint-disable @typescript-eslint/no-require-imports -- Node CJS test harness loads TypeScript without another dependency. */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('path');
const ts = require('typescript');

require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  }).outputText, filename);
};

const {
  FOUNDING_LIMITS,
  FOUNDING_SUBJECT_PREFIX,
  MAILTO_MAX_CHARS,
  buildFoundingMailto,
  emptyFoundingApplication,
  formatFoundingEmailBody,
  validateFoundingApplication,
} = require('../src/lib/foundingApplication.ts');
const { DEVELOPER } = require('../src/lib/links.ts');

function validApp(overrides = {}) {
  return {
    ...emptyFoundingApplication(),
    name: 'Ada Example',
    email: 'ada@example.com',
    roles: ['engineering'],
    why: 'I ship Flutter and Postgres, and I want to help keep the crypto honest.',
    ...overrides,
  };
}

test('a complete application encodes a mailto draft to the developer', () => {
  const checked = validateFoundingApplication(validApp({
    links: 'https://github.com/ada',
    location: 'UTC+5:30',
    hours: 'evenings',
    heard: 'the homepage Burn tool',
  }));
  assert.equal(checked.ok, true);
  const mail = buildFoundingMailto(DEVELOPER.email, checked.value);
  assert.equal(mail.to, DEVELOPER.email);
  assert.ok(mail.href.startsWith(`mailto:${DEVELOPER.email}?`));
  assert.match(mail.subject, new RegExp(`^${FOUNDING_SUBJECT_PREFIX}`));
  assert.match(mail.subject, /Ada Example/);
  assert.ok(mail.href.includes('subject='));
  assert.ok(mail.href.includes('body='));
  assert.equal(decodeURIComponent(mail.href.split('body=')[1] || ''), mail.body);
  assert.match(mail.body, /Engineering/);
  assert.match(mail.body, /https:\/\/github.com\/ada/);
  assert.match(mail.body, /UTC\+5:30/);
  assert.match(mail.body, /Evenings \/ weekends/);
  assert.match(mail.body, /the homepage Burn tool/);
  assert.equal(mail.truncated, false);
  assert.ok(mail.href.length <= MAILTO_MAX_CHARS);
});

test('validation rejects missing name, email, roles, and a too-short note', () => {
  const checked = validateFoundingApplication(emptyFoundingApplication());
  assert.equal(checked.ok, false);
  assert.ok(checked.errors.name);
  assert.ok(checked.errors.email);
  assert.ok(checked.errors.roles);
  assert.ok(checked.errors.why);
});

test('only invented role ids fail because nothing remains to apply for', () => {
  const checked = validateFoundingApplication(validApp({
    roles: ['ceo'],
  }));
  assert.equal(checked.ok, false);
  assert.ok(checked.errors.roles);
});

test('unknown role ids are dropped; remaining known roles still pass', () => {
  const checked = validateFoundingApplication(validApp({
    roles: ['ceo', 'design'],
  }));
  assert.equal(checked.ok, true);
  assert.deepEqual(checked.value.roles, ['design']);
  assert.match(formatFoundingEmailBody(checked.value), /Design/);
  assert.doesNotMatch(formatFoundingEmailBody(checked.value), /ceo/);
});

test('fields are clipped to the documented limits', () => {
  const checked = validateFoundingApplication(validApp({
    name: 'N'.repeat(FOUNDING_LIMITS.name + 40),
    links: 'L'.repeat(FOUNDING_LIMITS.links + 40),
    why: 'W'.repeat(FOUNDING_LIMITS.why + 40),
  }));
  assert.equal(checked.ok, true);
  assert.equal(checked.value.name.length, FOUNDING_LIMITS.name);
  assert.equal(checked.value.links.length, FOUNDING_LIMITS.links);
  assert.equal(checked.value.why.length, FOUNDING_LIMITS.why);
});

test('a huge note still produces a mailto under the client URL ceiling', () => {
  const checked = validateFoundingApplication(validApp({
    why: 'I would bring '.repeat(80),
    links: 'https://example.com/very/long/path/'.repeat(8),
  }));
  assert.equal(checked.ok, true);
  const mail = buildFoundingMailto(DEVELOPER.email, checked.value);
  assert.ok(mail.href.length <= MAILTO_MAX_CHARS, String(mail.href.length));
  assert.equal(mail.href.includes(' '), false);
});

test('mailto never claims a database insert and always names the developer inbox', () => {
  const src = fs.readFileSync(
    path.join(__dirname, '../src/components/FoundingTeamForm.tsx'),
    'utf8',
  );
  assert.match(src, /window\.location\.assign\(next\.href\)/);
  assert.match(src, /Nothing is stored in the NO SUS database/);
  assert.doesNotMatch(src, /supabase|fetch\(|Formspree/i);
  assert.match(src, /DEVELOPER\.email/);
});
