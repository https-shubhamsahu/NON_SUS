# AGENTS.md — NO SUS

**This is the single source of truth for this repository.** It is written for any AI coding agent
(Claude Code, Cursor, Codex, Copilot, Gemini CLI, …) and for humans. If you read one file before
touching this repo, read this one. `CLAUDE.md` is a pointer to this file, not a second copy.

Everything here is meant to be true *right now*. If you find a statement that contradicts the code,
the code wins — fix this file in the same commit.

---

## 0. Working agreement — read before editing

1. **Log your changes.** After every commit you make, add an entry to [§11 Change log](#11-change-log).
   A hook appends the mechanical row (date · hash · subject · files) automatically; you add the
   *why* when the change is architectural, changes a contract, or would surprise the next agent.
   See §11 for the exact protocol.
2. **Verification gates.** Do not claim a task is done until the relevant gate is clean:
   - Flutter: `flutter analyze` **and** `flutter test`
   - Rust (`services/fhe-compute/`): `cargo build && cargo test`
   - Homepage: `npm run build` in `homepage/`
   Report failures with the actual output. Never describe an unrun command as passing.
3. **Cryptographic honesty (load-bearing).** Copy, marketing, and UI must never outrun the actual
   cryptography. Don't claim screenshot-proofing in a browser (impossible) or "the server cannot
   see it" ahead of what is implemented. This rule outranks product polish — see
   `PROJECT_CONSTITUTION.md` §2.3.
4. **Edit in place.** No `_v2`/`_new`/`_final` duplicate files, no parallel branch iterations of the
   same feature. Remove dead code as you go.
5. **Migrations are append-only.** Every new table gets RLS. SQL migrations are incremental and
   idempotent, and are **never edited after they land**.
6. **Don't break shipped URL contracts.** Burn links are already in the wild — see §5.

---

## 1. What this project is

**NO SUS** — a secure study-group workspace (file sharing, watermarked viewing, burn notes/files,
audit logging) built with Flutter on a Supabase backend. Ships to web (GitHub Pages) and Android
(Play Store).

Current version: **`1.3.0+10`** (`pubspec.yaml`). Latest migration: `20260725000000_hardware_backed_device_id.sql`.

Four sub-projects live in this repo:

- **Root** — the Flutter app (`lib/`, `test/`, `android/`, `web/`).
- **`supabase/`** — Postgres migrations + Deno Edge Functions (15 of them: `burn-file-{init,confirm,fetch}`,
  `share-fetch`, `share-heartbeat`, `create-redemption-code`, `redeem-code`, `storage-router`,
  `drive-proxy`, `account-manager`, `cleanup-burn-files`, `verify-play-integrity`, plus the shelved
  `fhe-proxy`, `sealed-api`, `pact-matcher`).
- **`services/fhe-compute/`** — isolated Rust (TFHE-rs) homomorphic-compute service. Not V1 (§8).
- **`homepage/`** — Next.js marketing landing page, statically exported (`output: "export"`), served
  at the **`nosus.foo` root**. The Flutter web app lives at **`app.nosus.foo`** (deployed to a
  separate `nosus-app` repo). `.github/workflows/gh-pages.yml` has two independent jobs: `landing`
  (this repo's gh-pages) and `app` (needs `APP_DEPLOY_TOKEN`). A pre-paint shim in
  `homepage/src/app/layout.tsx` forwards legacy `nosus.foo/#/burn|burnfile|v|join/…` links and
  Supabase auth callbacks to the app subdomain (fragment preserved — **the AES key lives there**).
  The hero has REAL working Burn Note/File tools; their WebCrypto (`homepage/src/lib/burnCrypto.ts`)
  is kept byte-compatible with the Dart app by `test/unit/burn_crypto_web_compat_test.dart` — never
  change one side without the other. Cross-product URLs + dev identity live in
  `homepage/src/lib/links.ts`. It has its own `homepage/CLAUDE.md` / `homepage/AGENTS.md`; the
  vendored Next.js has breaking changes, so read `homepage/node_modules/next/dist/docs/` before
  writing code there. Keep its content honest: no invented testimonials, usage stats, or APIs that
  don't exist.

---

## 2. Commands

```sh
flutter pub get
flutter analyze                      # must be clean before claiming a task done
flutter test                         # all tests
flutter test test/unit/deep_link_parsing_test.dart   # single test file
flutter build web --base-href "/"    # web release (CI adds --dart-define-from-file=.env)
```

**This Windows machine:** the `flutter` on PATH (`C:\Users\shubh\flutter\bin`) is an EMPTY checkout —
the real SDK is `C:\Users\shubh\AppData\Local\flutter\bin\flutter.bat` (stable 3.44.4, matching CI).

**Rust service** (`services/fhe-compute/`): `cargo build && cargo test`. Toolchain is
scoop-installed `stable-x86_64-pc-windows-gnu` (no MSVC); needs scoop gcc + cargo on PATH:

```sh
export PATH="/c/Users/shubh/scoop/apps/gcc/current/bin:/c/Users/shubh/.cargo/bin:/c/Users/shubh/scoop/persist/rustup/.cargo/bin:/c/Users/shubh/scoop/shims:$PATH"
```

Real-crypto test suites are slow (~14 min). The gnu-linker workaround lives in
`services/fhe-compute/.cargo/config.toml` — don't remove it. The Rust `target/` dir is ~39 GB
locally (gitignored).

**Previewing web builds:** use the Browser pane with `.claude/launch.json` servers —
`web-release-static` serves `build/web` on :5051 (build first). Interactive click-through
verification in the preview harness is unreliable; diagnose briefly, then hand the click-through to
the user rather than chasing flaky rendering.

**Test layout:** `test/unit/` (crypto, deep links, version compare, constants), `test/widget/`
(auth, groups — semantics regression tests), `test/features/` (auth, groups, fhe, sealed),
`test/providers/`.

---

## Cursor Cloud specific instructions

Notes for agents running in the Cursor Cloud VM (a Linux box, **not** the Windows machine described
in §2). The startup update script only refreshes dependencies (`flutter pub get`; `npm ci` in
`homepage/`); everything below is already provisioned in the VM snapshot.

- **Flutter SDK lives at `~/flutter`** (stable `3.44.4`, matching CI — §3). It is on `PATH` via
  `~/.bashrc`, so `flutter`/`dart` work in a login shell. The §2 "Windows machine" `flutter.bat`
  paths do **not** apply here. Node comes from `nvm` (v22); `cargo` is preinstalled. Standard gates
  from §2/§0 apply unchanged: `flutter analyze` + `flutter test` for the app, `npm run lint` +
  `npm run build` in `homepage/`.
- **The backend is live, not mock.** `lib/config/supabase_credentials.dart` is populated with a
  hosted Supabase project (`rxfnazmusofikwaggntb.supabase.co`), so the app **and** the homepage burn
  tools run against a real backend by default — §4's "leave both fields empty → mock fallback" note
  describes the *empty* state, which is not the committed state. Consequence: `flutter test` includes
  `test/db_test.dart`, which talks to that hosted project, so the full suite **needs network access**
  and real accounts/burn notes created during testing hit the live project.
- **Run the app (web) for manual testing:** `flutter run -d web-server --web-hostname 0.0.0.0
  --web-port 5000`. The `web-server` device needs no Chrome and **compiles lazily on the first HTTP
  request** (~30 s to first paint) — a blank page right after start is normal; wait/refresh. Sign-up
  with email+password logs in immediately (email confirmation is not enforced), so you can reach the
  Workspace and exercise core features (e.g. Burn Notes) end-to-end without an inbox.
- **Run the homepage:** `npm run dev` in `homepage/` (Next.js on :3000). Its hero Burn Note/File
  tools are real and hit the same live Supabase backend.
- **Do not build `services/fhe-compute/` unless working on FHE** — it's shelved (§8), its `target/`
  is ~39 GB and its tests take ~14 min.

---

## 3. CI & release

- **`.github/workflows/gh-pages.yml`** — on push to `main`: analyze, test, build web, deploy to
  GitHub Pages. It writes `nosus.foo` into `build/web/CNAME`; the deploy action's `cname` input does
  nothing on the pinned version, so **keep that step**.
- **`.github/workflows/play-store-release.yml`** — on `v*.*.*` tags: analyzes, **runs `flutter test`**
  (release-gating — a broken suite blocks the build, not just local dev), builds a signed AAB
  (keystore from the `ANDROID_KEYSTORE_BASE64` secret; **without `android/key.properties` the Gradle
  config silently falls back to debug signing**), publishes a GitHub Release with the APK (what the
  `releases/latest` download buttons serve), then uploads to the Play internal track.

**After tagging a release**, bump the `app_latest_version` row in `remote_configs` — it drives the
in-app update banner (`lib/features/config/presentation/providers/app_update_provider.dart`).

Paste-ready Play Console listing copy + data-safety answers live in `store_listing/` — **every claim
there must map to a shipped feature.** Both workflows use `subosito/flutter-action`'s `cache: true`
and write a `SENTRY_DSN` line into `.env` (empty/no-op unless that secret is ever set — see §8).

**Signing keys:** the upload keystore is `android/app/upload-keystore.jks` (alias `nosus-upload`,
RSA 2048), passwords in git-ignored `android/key.properties`. The five CI secrets
(`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`) were confirmed present on the repo as of 11 July 2026. Losing
this keystore means losing the ability to update the app under this signing identity — see §9.

---

## 4. Architecture

**State management:** Riverpod 3 (`flutter_riverpod` ^3.3.1). Entry point `lib/main.dart` wires
Supabase init, deep-link handling (`app_links`), and a `PageView` tab shell — in order: **Workspace,
Vault, Study Desk, Audit Log, Groups** (`lib/components/floating_nav.dart` defines the labels/icons;
`activeTabProvider` drives the index). Profile is **not** a tab — it's pushed as a route from the
avatar button in the header. `SharedPreferences` is awaited once in `main()` and injected via
`sharedPreferencesProvider.overrideWithValue(prefs)` so theme resolves synchronously on first build.

**Feature-first layout:** `lib/features/<feature>/` with `data/` (clients, repositories), `domain/`
(entities), `presentation/` (screens, widgets, providers). Older features (e.g. `groups`) are
flatter (`screens/`, `widgets/`, `providers/` at feature root) — match whichever style the feature
you're editing already uses. Access data only through repositories from presentation code; don't
call Supabase clients directly from widgets in Clean-Architecture features.

Features: `admin`, `audit`, `auth`, `config`, `fhe`, `files`, `focus`, `groups`, `notes`,
`onboarding`, `profile`, `sealed`, `share`, `vault`, `workspace`.

**Cross-cutting layers:**

- `lib/services/` — singletons: `supabase_service.dart`, `audit_service.dart`,
  `screenshot_guard.dart`, `device_integrity_service.dart`, `risk_engine_service.dart`,
  `web_security_guard.dart`, `burn_file_crypto.dart`, `play_integrity_service.dart`
- `lib/core/` — Supabase bootstrap + providers (`core/supabase/`), theme provider, mascot (Rive), utils
- `lib/config/` — `supabase_credentials.dart` (**leave both fields empty → app runs in mock fallback
  mode with no backend**), `fhe_config.dart`, `storage_router_config.dart`,
  `crash_reporting_config.dart`
- `lib/components/` — shared widgets used across features. The document-watermarking stack
  (`SpyglassViewer` → `secure_viewer/secure_document_viewer.dart` composing `watermark_overlay.dart`
  + `blur_reveal_layer.dart`, wired to `ScreenshotGuard`, `AuditService`, and device/risk state) is
  the one place that implements the product's core "watermarked viewing" promise, and it's consumed
  from Workspace, Vault, and Groups rather than owned by any single feature — **check here before
  assuming watermarking logic lives in a feature folder.**

**Backend:** everything goes through Supabase — auth, storage, Postgres (schema history in
`supabase/migrations/`, heavy RLS use), and Edge Functions for anything secret-touching (burn files,
share fetch/heartbeat, FHE proxy). Client-side crypto (AES via `encrypt`) is used for burn
notes/files; keys travel in URL fragments, never to the server.

**Riverpod rebuild scoping:** `StudyGroup`/`GroupMember`
(`lib/features/groups/domain/models/study_group.dart`) have explicit `==`/`hashCode` — added
specifically so `group_detail_screen.dart` can `ref.watch(groupsProvider.select(...))` down to just
its one group instead of rebuilding the whole screen whenever *any* group changes. Don't drop that
equality override without checking that call site; without it `.select()` **silently** stops working
(every list emission produces new instances that compare unequal by identity, so the "optimization"
becomes a no-op, not a crash — easy to miss).

**Mascots (Lux/Nox):** two Rive-driven characters (`assets/mascot/*.riv`) that react to app state —
see `MASCOT_GUIDE.md` for the full mood table. Driven imperatively via Riverpod, e.g.
`ref.read(luxMascotProvider.notifier).play(MascotMood.lookAround)`. Never let a mascot occupy content
space; respect `MediaQuery.disableAnimations` (locks to `MascotMood.idle`).

---

## 5. Load-bearing contracts — break these and production breaks

**Deep-link URL contract.** `extractBurnNoteToken` / `extractBurnFileToken` / `extractBurnFilesToken`
in `lib/main.dart` are public and covered by `test/unit/deep_link_parsing_test.dart`. Burn links are
already shared into the wild — silently changing what parses is a production outage. **Keep legacy
formats parsing.**

**Burn Files: single vs. multi-file share.** `#/burnfile/<id>?k=&v=` (singular) is the original
one-file link, untouched. `#/burnfiles/<id1,id2,...>?k=<key1,key2,...>&v=<iv1,iv2,...>` (plural) is
an additive multi-file link — same per-file AES-CBC crypto as always (each file keeps its own
independent key/IV; **no new crypto primitive**), just N of them joined by commas.
`BurnFileViewerScreen` takes `List<({String id, String keyHex, String ivHex})> files` (a record type,
not a class, to avoid a feature-screen → `main.dart` import) and handles both shapes identically — a
single-file share is just a one-element list. The creator (`burn_file_creator_screen.dart`) runs
every file's encrypt→init→upload→confirm pipeline **in parallel** via `Future.wait`, with AES
encryption offloaded to a `compute()` isolate — that parallelism, not any server change, is what
makes multi-file shares fast. A share is capped at **25MB combined** (`_maxTotalBytes`, checked
client-side before any upload starts) and **10 files** (`_maxFilesPerShare`); the per-file ceiling is
enforced authoritatively server-side via the live-tunable `remote_configs.burn_files_max_size_bytes`
row (both `burn-file-init` and `burn-file-confirm` read it dynamically — changing that one row, no
code deploy, is how the cap is tuned). Redemption codes (`create-redemption-code`/`redeem-code`) stay
**single-target only** — a multi-file share only gets the link, never a short code. The homepage's
own burn-file tool (`homepage/src/components/BurnTool.tsx`) is deliberately still single-file-only;
only its size-cap constant (`FILE_MAX_BYTES` in `burnApi.ts`) was kept in sync at 25MB.

**App id / custom scheme.** `foo.nosus.app` (reverse-DNS of `app.nosus.foo`) is both the Android
applicationId and the custom URL scheme (`foo.nosus.app://v/…`, `://open`, `://join/…`). It must stay
identical everywhere it appears: `android/app/build.gradle.kts`, `AndroidManifest.xml`,
`ios/Runner/Info.plist`, `lib/main.dart`,
`lib/features/share/.../anonymous_share_viewer_screen.dart`, `homepage/src/lib/appLaunch.ts`, and the
`packageName` in `play-store-release.yml`. The OAuth callback scheme `io.supabase.nosus` is
**intentionally different** (it's registered with Supabase auth) — do not "fix" it to match.

**Web↔Dart crypto compatibility.** `homepage/src/lib/burnCrypto.ts` and the Dart burn crypto must
stay byte-compatible; `test/unit/burn_crypto_web_compat_test.dart` is the guard. Never change one
side alone.

---

## 6. Backend notes & accepted trade-offs

**Burn Notes rate limiting.** Unlike Burn Files (edge-function-fronted, real per-IP-hash counter),
Burn Notes insert **directly from the client** into `burn_notes` — no edge-function hop, by design,
for speed. `check_burn_note_velocity()` (trigger on `burn_notes`, added in
`20260721000000_security_hardening_and_burn_note_rate_limit.sql`) is a coarse, **IP-blind global
circuit breaker** (>120 inserts/minute globally → reject), not a per-client limit — Supabase's
connection pooler means a real per-IP limit here would need routing through an edge function, a
trade-off deliberately *not* taken to keep the direct-insert path fast. Don't "fix" this into a full
rate limiter without re-checking whether that speed trade-off still holds.

**Known accepted advisor finding.** `pg_net` lives in the `public` schema (Supabase security advisor:
`extension_in_public`). `ALTER EXTENSION pg_net SET SCHEMA` is unsupported by that extension — the
only real fix is drop+recreate, which risks cascading into anything using `net.http_post`. Left
as-is; don't attempt the move without checking every `net.http_post` call site first.

**Security posture:** RLS on all tables; audit hash-chains (`verify_audit_chain`); replay protection
(nonce + timestamp); no key material in Supabase (metadata only); no plaintext/ciphertext/keys
logged.

---

## 7. Accessibility

Custom tappable widgets (`GestureDetector`/`InkWell` standing in for a button) need an explicit
`Semantics(button: true, label: '...', child: ...)` wrapper — Flutter gives none of that for free on
a bare `GestureDetector`. The highest-traffic surfaces (bottom nav, auth screens, burn
creator/viewer, groups) already follow this; `test/widget/auth_screen_test.dart` and
`groups_screen_test.dart` have regression tests checking specific `Semantics` widgets'
`properties.label`/`properties.button` **directly** (more reliable in this codebase than
`find.bySemanticsLabel` + the rendered semantics tree, which didn't reliably resolve during testing).
Icon-only tap targets should generally just be `IconButton` (48dp minimum + tooltip-as-label for
free) rather than a hand-wrapped `GestureDetector`+`Icon`.

**Still outstanding:** onboarding, `upload_modal.dart`, `save_to_no_sus_dialog.dart`,
`profile_screen.dart` secondary actions, `empty_states.dart`.

---

## 8. Subsystems that are scaffolded, shelved, or off

**FHE / Sealed — long-term vision, not V1.** FHE (`lib/features/fhe/`, `services/fhe-compute/`,
`supabase/functions/fhe-proxy/`) is long-term-vision infrastructure per `PROJECT_CONSTITUTION.md` §4
— not V1 scope, not the active product. `lib/features/sealed/` and the `sealed-api`/`pact-matcher`
edge functions specifically are **shelved** (kept in the repo, not shipped — `SHIELD.md` documents
the architecture). Detailed guardrails live in `.claude/rules/no-sus-fhe.md` (mirrors
`.cursor/rules/no-sus-fhe.mdc`), which loads automatically when touching FHE files. Summary:
additive only, off by default behind granular flags in `lib/config/fhe_config.dart` (never a single
global switch), Flutter never talks to TFHE directly (app → `FheTransport` → `fhe-proxy` → Rust),
never log or persist key material.

**Crash reporting (Sentry) — off by default.** `lib/config/crash_reporting_config.dart` (`SENTRY_DSN`
empty). Wired into `FlutterError.onError` and the `runZonedGuarded` handler in `lib/main.dart` via
the low-level `SentryFlutter.init(configure)` call (no `appRunner:` — kept out of the existing
bootstrap sequence deliberately). `sendDefaultPii = false` and tracing stays at **0% always** — this
product's whole premise is zero-knowledge/no-tracking, so don't casually raise either without
reading `store_listing/data_safety_answers.md`'s note first (enabling it flips a Data Safety answer
from "not collected" to "collected").

**Device identity is hardware-backed on Android (Stage 1 of 2).** `DeviceIntegrityService.deviceId`
returns the SHA-256 of a non-extractable EC keypair's public key, generated in the Android Keystore
by `KeyAttestationManager.kt` (StrongBox → TEE → software fallback, exposed as `getDeviceKeyId` on
the *existing* `co.nosus.app/device_integrity` channel). It replaced a `Uuid().v4()` stored in
plaintext SharedPreferences — editable on exactly the rooted devices this service exists to detect,
which made two detectors defeatable: flag-washing (delete the pref, get a clean id) and nulling
`multiple_device_access` outright (report one id from every device). Web, iOS, and any device whose
Keystore is unusable keep the legacy UUID path unchanged. `deviceIdSecurityLevel` reports the
backing actually granted; **`'software'` or `null` means the id is *not* hardware-protected** — copy
must not imply otherwise.

*Verified on real hardware* (OnePlus CPH2487, Android 16, bootloader locked / `verifiedbootstate:
green`): reports `backing=tee`, and the id is byte-identical across a force-stop and relaunch under
two different PIDs — i.e. the `containsAlias` lookup really does return the persisted key rather
than silently regenerating. That device advertises `hardware_keystore` but **not**
`strongbox_keystore`, so it also exercises the StrongBox→TEE fallback. Emulators report
`backing=software` and that is correct output, not a bug — they have no TEE. The one path still
unexercised is the DB side: `migrate_device_id()` has never run against a real signed-in session,
because verification was done on a device that wasn't logged in. **Stage 2 — server-side verification of the attestation certificate chain,
which is what would actually *prove* the id came from hardware rather than trusting the client's
word — is deliberately not built.** It needs a physical Android device to test against (emulators
attest with Google's known-compromised debug key at `securityLevel: Software`), and shipping it
emulator-only would create a second never-exercised security scaffold next to Play Integrity. Worth
knowing: it needs **no** Google Cloud project (offline chain validation against Google's published
roots), so it is *not* blocked by what blocks Play Integrity below.

**Never rewrite `device_integrity_events.device_id`.** `migrate_device_id()`
(`20260725000000_hardware_backed_device_id.sql`) renames the `user_known_devices` row on upgrade,
carrying `first_seen_at` across so the id-format change doesn't make every already-known device look
new and flood the ledger with false `multiple_device_access` findings. It deliberately leaves
`device_integrity_events` alone: that table's `entry_hash` is computed over `device_id` by a **BEFORE
INSERT** trigger (`20260710010000_security_hardening.sql`), so an `UPDATE` would not recompute it and
would silently break `verify_device_integrity_chain()`. Historical findings correctly stay recorded
against whichever id was current when they were observed.

**Play Integrity — scaffolded, never exercised.** `AppIntegrityConfig.enabled` (default false) gates
`lib/services/play_integrity_service.dart`, which calls native `PlayIntegrityManager.kt`
(`android/app/.../security/`, registered as the `co.nosus.app/play_integrity` MethodChannel in
`MainActivity.kt`) and forwards the token to the deployed-but-unconfigured `verify-play-integrity`
edge function. This is real, structurally-correct code (the edge function reuses
`drive-proxy/index.ts`'s proven Google-service-account JWT pattern) but **has never been exercised
against a real device-generated token.** Three things block it: `PlayIntegrityManager.kt`'s
`cloudProjectNumber` is `0` (fails fast on purpose), the edge function's
`PLAY_INTEGRITY_SERVICE_ACCOUNT_EMAIL`/`PLAY_INTEGRITY_PRIVATE_KEY` secrets aren't set (**don't
assume `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — used for Play publishing — has Play Integrity API scope**;
this needs its own service account, same convention as `drive-proxy`'s `GD_SERVICE_ACCOUNT_EMAIL`),
and `AppIntegrityConfig.enabled` is false. Read `AppIntegrityConfig`'s doc comment before enabling
anything.

---

## 9. Open threads

Verified against the repo on 2026-07-25. Items marked **(manual)** cannot be verified from the
codebase — assume still outstanding unless you know otherwise.

| Item | Status |
|---|---|
| Back up `android/app/upload-keystore.jks` + `key.properties` outside the repo | **(manual)** — losing these forfeits the signing identity |
| Play Console: upload feature graphic, phone/tablet screenshots, enter Data Safety answers, add Internal Testing testers | **(manual)** — assets drafted in `store_listing/` |
| `google_fonts` fetches Inter/Outfit from Google's CDN at runtime | Open — verified: no `allowRuntimeFetching = false`, no `.ttf` bundled in `pubspec.yaml` assets. Fix = bundle real font binaries locally |
| Accessibility sweep on lower-traffic screens | Open — see §7 |
| `BURN_FILES_IP_SALT` not set | Open — burn-file per-IP rate limiting degrades without it |
| Orphaned keystore `android/app/release_orphaned_2026-06-21.keystore` | On disk, git-ignored — delete once confirmed unneeded |

---

## 10. Other docs — what to trust

| Doc | Trust |
|---|---|
| **This file** | ✅ Kept current every session |
| `PROJECT_CONSTITUTION.md` | ✅ Authoritative for product vision, honesty rules, non-negotiables |
| `RELEASE_REPORT.md` | ✅ Release-readiness audit (10–11 July 2026); §12 checklist still useful |
| `SHIELD.md` | ✅ Architecture of the shelved Sealed/FHE subsystem |
| `MASCOT_GUIDE.md` | ✅ Mascot mood table |
| `homepage/CLAUDE.md`, `homepage/AGENTS.md` | ✅ Scoped to the Next.js landing page |
| `.claude/rules/no-sus-fhe.md` | ✅ FHE guardrails (auto-loads) |
| `docs/archive/*` | ❌ **Historical snapshots.** Superseded; several declare themselves "the single source of truth" and contradict both this file and each other |

---

## 11. Change log

> **Protocol.** Newest first. A `PostToolUse` hook (`.claude/hooks/log-commit.sh`, wired in
> `.claude/settings.json`) appends the mechanical row automatically after any successful `git commit`
> — you do not need to write it by hand. **Your job is the "why".** After committing, edit the entry
> the hook just added and append a `— why:` clause when the change:
> touches a contract in §5 · changes architecture · adds/removes a dependency · makes a trade-off ·
> or would otherwise surprise the next agent. Purely mechanical commits (typos, formatting, version
> bumps) need no `why`.
>
> Also update the *body* of this file in the same commit when the change makes something above
> untrue. The log records what happened; the sections above record what is true now.
>
> Keep roughly the **30 most recent** entries here. Older history lives in `git log` — trim from the
> bottom rather than letting this section grow without bound.

<!-- CHANGELOG:INSERT -->

- **2026-07-25** · `96efcac` · ci: bump softprops/action-gh-release to v3

- **2026-07-25** · `d6a1c1d` · fix(ci): pin actions/checkout to v5 — v6+ breaks the cross-repo deploy

- **2026-07-25** · `8718c08` · ci: bump actions/checkout and actions/setup-node to v7

- **2026-07-19** · `bf48c97` · docs: add root README documenting product, architecture, and monorepo layout

- **2026-07-25** · `b795cc4` · docs(agents): log 4905e42 in the change log

- **2026-07-25** · `4905e42` · docs(agents): add the "why" for cfab7c8, fix two stale references

- **2026-07-25** · `cfab7c8` · feat(security): hardware-backed device identity on Android — why:
  `DeviceIntegrityService.deviceId` was a `Uuid().v4()` in plaintext SharedPreferences, so the two
  detectors built on it were defeatable by editing one file on a rooted device — the exact
  population they target. It is now a digest of a non-extractable Android Keystore key (§8).
  Contract note: `migrate_device_id()` must never be "improved" into also rewriting
  `device_integrity_events.device_id` — that table's `entry_hash` is computed over `device_id` by a
  **BEFORE INSERT** trigger, so an UPDATE would not recompute it and would silently break
  `verify_device_integrity_chain()`. Trade-off: if the migration is needed and fails, the client
  skips device registration for that session rather than risk writing a false
  `multiple_device_access` into an append-only chain it could never retract.

- **2026-07-25** · consolidated project documentation into this file — why: three root docs
  (`ANALYZE_RESULT.md`, `INTEGRATION_REPORT.md`, `PROJECT_HANDOVER.md`) each separately claimed to be
  "the authoritative single source of truth", none referenced each other consistently, and none were
  kept in sync — a future agent picking one at random would act on stale information (e.g.
  `PROJECT_HANDOVER.md` still described the product as "SecureSend" and listed already-fixed bugs).
  They are now in `docs/archive/`. `CLAUDE.md` is a pointer to this file.

_Entries before this point predate the consolidation and live in `git log` and `docs/archive/`._
