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

Current version: **`1.4.0+11`** (`pubspec.yaml`). Latest migration: `20260801062256_revoke_internal_function_execute.sql`.

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
avatar button in the header, and Settings is pushed from Profile. The header also carries the
notification bell (`_NotificationBell` in `main.dart`, badge driven by
`unreadNotificationCountProvider`). `SharedPreferences` is awaited once in `main()` and injected via
`sharedPreferencesProvider.overrideWithValue(prefs)` so theme resolves synchronously on first build.

**The app is no longer auth-walled at the front door.** `AuthGate` renders `WelcomeScreen` for a
signed-out visitor (not `AuthScreen`), which explains the product and hands over the three features
that are genuinely anonymous on both ends — Burn Notes, Burn Files, code redemption. It pushes
`AuthScreen` when the user asks for it, or when they reach for something that needs identity. A
returning user who has already seen it (`welcomeSeenProvider`) goes straight to the form, which
keeps an "Explore without an account" link back.

**Auth walls must preserve intent.** `pendingIntentProvider`
(`features/auth/presentation/providers/pending_intent_provider.dart`) parks what the user was trying
to do in SharedPreferences — durable, because signup can round-trip through an email link or an
OAuth browser hand-off that takes the process down — and `_WorkspaceHomeState._resumePendingIntent`
replays it after the shell's first frame. It reads the legacy `pending_invite_code` key too, so an
app updated mid-flow doesn't drop the invite. Don't add a new auth wall without setting an intent.

**Feature-first layout:** `lib/features/<feature>/` with `data/` (clients, repositories), `domain/`
(entities), `presentation/` (screens, widgets, providers). Older features (e.g. `groups`) are
flatter (`screens/`, `widgets/`, `providers/` at feature root) — match whichever style the feature
you're editing already uses. Access data only through repositories from presentation code; don't
call Supabase clients directly from widgets in Clean-Architecture features.

Features: `admin`, `analytics`, `audit`, `auth`, `config`, `fhe`, `files`, `focus`, `groups`,
`help`, `notes`, `notifications`, `onboarding`, `profile`, `sealed`, `settings`, `share`, `vault`,
`workspace`.

**Onboarding is two surfaces, not a slideshow.** `WelcomeScreen` (pre-auth, explained above) and
`GetStartedScreen` (post-signup, one screen, both fields optional and a real Skip). The six-act
narrative that used to run *after* signup is gone. Completion is recorded per-account in
SharedPreferences by `OnboardingNotifier` — it stores the completing user's id, not a boolean, so a
second account on the same device still gets setup while the first doesn't repeat it. Contextual
tips are separate again: `CoachMarks.showSequence` (`lib/components/coach_mark.dart`) with per-tip
state in `tourProgressProvider`, replayable from Help and Settings.

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

**Android App Links are host-wide, and `_routeIncomingWebLink()` is what stops that being a bug.**
`AndroidManifest.xml` carries an `android:autoVerify="true"` filter for `https://app.nosus.foo`,
verified against `web/.well-known/assetlinks.json`. It **cannot** be path-scoped: an intent filter
has no way to match a URL fragment, and every link the app mints is fragment-shaped at path `/`
(`/#/burn/…`, `/#/burnfile/…`, `/#/burnfiles/…`, `/?cb=…#/v/…`, `/#/join/…`). So an installed app
intercepts *every* link to that host. `_routeIncomingWebLink()` in `lib/main.dart` must therefore
handle every shape the app can mint — **add a new link shape without adding it there and the link
dead-ends on the home screen**, silently, with no browser fallback, because the system already chose
the app over the web page. It is the native mirror of the `Uri.base` branches that run in `main()`
on web. `web/.nojekyll` is load-bearing for the same feature: without it GitHub Pages drops the
`.well-known` dot-directory and verification fails. The fingerprint in `assetlinks.json` is the Play
**app signing** key — pressing "Change key" in Play Console invalidates it.

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
applicationId and the custom URL scheme. Only **two** hosts are actually registered in
`AndroidManifest.xml` — `foo.nosus.app://v/…` (share view) and `://open` (the website's plain "open
in app"). `extractInviteToken` *parses* `foo.nosus.app://join/…` and a test pins that, but no intent
filter claims that host, so Android never delivers it; invite links ship as `…/#/join/<code>` https
URLs instead. Don't rely on the custom-scheme join form without adding the filter first.

The id must stay identical everywhere it appears: `android/app/build.gradle.kts` (`applicationId`
*and* `namespace`), `AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/main.dart`,
`lib/features/share/.../anonymous_share_viewer_screen.dart`, `homepage/src/lib/appLaunch.ts`,
`PACKAGE_NAME` in `supabase/functions/verify-play-integrity/index.ts`, the Kotlin package under
`android/app/src/main/kotlin/foo/nosus/app/`, and the `packageName` in `play-store-release.yml`. It
is also the id a future `google-services.json` must be issued for. The OAuth callback scheme
`io.supabase.nosus` is **intentionally different** (it's registered with Supabase auth) — do not
"fix" it to match.

The non-shipped desktop/iOS targets are still on Flutter's template defaults (`com.example.noSus`,
`com.example.no_sus`). That is deliberate neglect, not drift — rename them only if those platforms
ever ship.

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

The sweep is **done** as of 2026-07-29 — every `GestureDetector`/`InkWell` in `lib/` that acts as a
button now carries a label. Two deliberate exceptions, both correct as-is:

- **`profile_screen.dart`'s email tap** is a hidden easter egg (5 taps → advanced settings). It is
  left as plain text on purpose; announcing it as a button would leak a deliberately-hidden route.
- **`workspace_tab.dart`'s recently-saved row** is left unwrapped because its own children already
  read out (title + destination) and it contains an independently-focusable RETRY button. A parent
  label would either duplicate the row text or swallow the button.

Note the repo is **not** kept `dart format`-clean (108 of 157 files under `lib/` differ), so don't
run `dart format` across a file you are only editing a few lines of — it buries the real change.

---

## 8. Subsystems that are scaffolded, shelved, or off

**FHE / Sealed — long-term vision, not V1, and now absent from the UI.** FHE
(`lib/features/fhe/`, `services/fhe-compute/`, `supabase/functions/fhe-proxy/`) is long-term-vision
infrastructure per `PROJECT_CONSTITUTION.md` §4 — not V1 scope, not the active product.
`lib/features/sealed/` and the `sealed-api`/`pact-matcher` edge functions specifically are
**shelved** (kept in the repo, not shipped — `SHIELD.md` documents the architecture).

As of 2026-07-29 Sealed is also gone from the **product surface**, pending a separate redesign.
`_SealedTeaserCard` used to occupy the first slot on the Workspace tab: a scripted ASCII
"simulation" followed by a star rating, checkboxes and free-text feedback that were **discarded on
`Navigator.pop`** while the app said "Verification submitted to the secure ledger." Both the dead
control and the false confirmation are removed. `SealedHomeScreen` and `FheDemoScreen` remain
unrouted — `test/unit/sealed_removed_test.dart` fails if anything outside `lib/features/{sealed,fhe}/`
references them, so the code can stay without the surface coming back by accident.

Detailed guardrails live in `.claude/rules/no-sus-fhe.md` (mirrors
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

**Measure (measure.sh) — off by default, Android-only, and deliberately
crash-only.** `measure_flutter` ^0.6.0, gated by
`lib/config/measure_reporting_config.dart` on `MEASURE_API_KEY` +
`MEASURE_API_URL` (both required), same `--dart-define`/`.env` convention as
`SENTRY_DSN`. Sentry is untouched and still independently gated — if both are
ever configured, both report.

Three things about this integration are non-obvious and easy to undo by accident:

1. **It is initialised *after* `FlutterError.onError` is assigned in `main()`, on
   purpose.** Measure's `init` captures whatever handler is installed at that
   instant and calls it after its own, so the current order chains
   Measure → Sentry → `presentError`. Hoist it above that assignment and the
   assignment overwrites Measure's handler — leaving an SDK that is configured,
   reports nothing, and looks healthy. It is also called with an empty action
   callback rather than Measure's documented `init(() => runApp(...))` form,
   because this bootstrap has several early-return `runApp()` branches for
   share/burn deep links; `init` only awaits its own setup before invoking the
   callback, so this is equivalent (same reasoning as the low-level
   `SentryFlutter.init` form).
2. **Credentials are plumbed twice from one file, and that is not redundancy.**
   The native SDK has *no* Dart-side init path — `measure_flutter`'s
   MethodChannel exposes `start`/`stop`/`trackEvent` but no `init` — so it must
   come up in `Application.onCreate`, which is why `android:name` on
   `<application>` is now `.NoSusApplication` instead of Flutter's
   `${applicationName}` placeholder. That class reads manifest meta-data
   injected by `android/app/build.gradle.kts` out of the repo-root `.env`, the
   same file `--dart-define-from-file` feeds the Dart gate. Both sides skip
   initialisation when either value is blank. `NoSusApplication` pins
   `trackActivityIntentData = false`: every link this app mints carries its AES
   key in the fragment and arrives as Activity intent data, so flipping that
   would upload plaintext decryption keys. Don't delete it as "already the
   default" — it is pinning a default that must never drift.
3. **Two of Measure's defaults are hostile to this product.** Screenshot-on-crash
   (`crash_take_screenshot`) is in the SDK's *server-driven* dynamic config,
   defaults to **on**, and is not settable from app code at all — it has to be
   disabled in the Measure dashboard, and until it is, a crash in a burn viewer
   or `SpyglassViewer` can upload decrypted content. `MainActivity`'s
   `FLAG_SECURE` blanks the `PixelCopy` capture path on API 26+ but not the
   Canvas fallback on older devices, so it is mitigation, not a guarantee.
   Separately, `ClickData` carries `label`/`semanticLabel` — note titles, group
   names, filenames in this app — which is why the app is **not** wrapped in
   `MeasureWidget` and `MsrNavigatorObserver` is **not** installed. That makes
   this crash + app-health only, with no interaction timeline, by choice.
   Adding either wrapper is a Data Safety change; read
   `store_listing/data_safety_answers.md` first.

Incidental: `measure_flutter` pulls `image_picker` transitively (for bug-report
attachments, a feature this app doesn't use). Checked — it contributes a
FileProvider and a Play-services module-dependency service to the merged
manifest, **no permissions**, so §7's "still no storage/media permissions"
stance is intact.

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

**Every `(manual)` item now has step-by-step instructions in [`MANUAL_TASKS.md`](./MANUAL_TASKS.md)**
— written for the repo owner, verified against the live project on 2026-07-29. Keep the two in sync.

| Item | Status |
|---|---|
| **A whole feature set is uncommitted** — notifications, settings, help, analytics, onboarding rewrite, group moderation | Open — analyze/test clean, but `v1.3.0` does **not** contain it. See `MANUAL_TASKS.md` §0 |
| **Four migrations not applied** (`20260727*`) | Open — newest applied is `20260725025159`. One of them rewrites `study_groups`/`profiles` RLS |
| `send-push` edge function not deployed | Open — verified against the live project; push needs Firebase + FCM secrets. The inbox works without it |
| Google Play Android Developer API disabled on Cloud project `694624182770` | **(manual)** — fails the last CI step; re-run needs no new tag |
| Android App Links wired but unverified | Code + `assetlinks.json` shipped 2026-07-30 (see §5). Verification needs a **Play-signed** build on a device — a debug APK always reports `verified: false`. Blocked behind the row above |
| `app_latest_version` still `1.2.0` in `remote_configs` | **(manual)** — bumping it prompts every existing user |
| Back up `android/app/upload-keystore.jks` + `key.properties` outside the repo | **(manual)** — losing these forfeits the signing identity |
| Play Console: upload feature graphic, phone/tablet screenshots, enter Data Safety answers, add Internal Testing testers | **(manual)** — assets drafted in `store_listing/`; shipping analytics changes the Data Safety answers |
| `google_fonts` fetches Inter/Outfit from Google's CDN at runtime | ✅ Closed 2026-08-01 (`cd514aa`) — Inter/Outfit/VT323 `.ttf` bundled in `assets/google_fonts/` (~1.6 MB), `allowRuntimeFetching = false` in `main()`. Adding a weight without its `.ttf` now falls back silently |
| ~~Accessibility sweep on lower-traffic screens~~ | **Done** 2026-07-29 — see §7 |
| `BURN_FILES_IP_SALT` not set | Open — burn-file per-IP rate limiting degrades without it |
| `migrate_device_id()` never exercised against a signed-in session | Open — needs a physical device; all `user_known_devices` rows are still legacy UUIDs |
| Orphaned keystore `android/app/release_orphaned_2026-06-21.keystore` | On disk, git-ignored — delete once confirmed unneeded |
| **Measure Android build never compiled locally** | Open — `flutter analyze` + `flutter test` are clean, and `Measure.init`/`MeasureConfig(autoStart, trackActivityIntentData)` were checked against the pinned `android-v0.18.0` tag, but `NoSusApplication.kt`, the manifest placeholders and the merged manifest have **not** been through a real Gradle build: this machine OOM'd (1.4 GB free of 15.6 GB, paging file too small for even a 1 GB JVM heap). First Android build after this must be watched |
| **(manual)** Measure dashboard: disable `crash_take_screenshot` | Open — server-side setting, **not** controllable from app code. Until it's off, a crash in a burn/document viewer can upload decrypted content (§8). Only matters once `MEASURE_API_KEY`/`MEASURE_API_URL` are set |

---

## 10. Other docs — what to trust

| Doc | Trust |
|---|---|
| **This file** | ✅ Kept current every session |
| `MANUAL_TASKS.md` | ✅ Operator checklist — console logins, credentials, device tests, product calls. Deliberately *not* guidance; mirrors §9 |
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

- **2026-08-01** · `281a9a3` · fix(db): fold in the renumbering rationale comment

- **2026-08-01** · `ee95653` · fix(db): renumber colliding 20260707000000 migration to 000001

- **2026-08-01** · `19c6104` · docs(agents): log d8dd915 in the change log

- **2026-08-01** · `d8dd915` · feat: wire Measure (measure.sh) crash/session monitoring, off by default

- **2026-08-01** · `22ae883` · docs(agents): log ea81f20 in the change log

- **2026-08-01** · `ea81f20` · docs(agents): add the "why" for this release, refresh stale header facts

- **2026-08-01** · `cd514aa` · feat: ship the 1.4.0 feature set and bundle fonts locally — why:
  this was ~60 files of unshipped work in the working tree; tag `v1.3.0` points at `6015dc3`, which
  contains none of it. Released as **1.4.0+11** rather than reusing 1.3.0 so one version string does
  not describe two very different builds. Two contract notes. (1) Fonts now resolve **only** from
  `assets/google_fonts/` — `GoogleFonts.config.allowRuntimeFetching = false` is set in `main()`
  before the early-return `runApp()` paths for share/burn deep links, because google_fonts reads the
  flag when a style is first resolved, not at package load. Adding a weight or family to
  `theme.dart` without adding its `.ttf` makes that style fall back silently, with no error.
  (2) Migration filenames now match the applied ledger exactly (`20260706223526`, `20260730115330`,
  `20260801062256`); they must stay matched or `supabase db push` re-runs landed migrations and
  writes duplicate ledger rows. **Data Safety changes with this release** — `analytics_events` is
  the first thing here collecting data for the team rather than the user, so the Play questionnaire
  must be resubmitted before it reaches testers.

- **2026-08-01** · `f3f65e8` · docs: add MANUAL_TASKS.md operator checklist
- **2026-08-01** · `6d972d1` · feat(links): serve assetlinks.json so app.nosus.foo App Links verify — why:
  the `autoVerify` filter had been in the manifest while
  `https://app.nosus.foo/.well-known/assetlinks.json` returned **404** — the file lived only in the
  working tree, so Android had nothing to verify against and every app.nosus.foo link opened in the
  browser. Committing it *is* the fix: `gh-pages.yml` deploys on push to `main`. The fingerprint is
  the Play **app signing** key, not the upload key; rotating it in Play Console silently breaks
  every App Link until this file is updated and redeployed.

- **2026-08-01** · `a6700cf` · fix(security): require group membership for drive-proxy download and
  delete — why: `drive-proxy` authenticated the caller and then served the file with the Google
  **service account**, which can read every file in the parent folder — authentication without
  authorization. Any signed-in user could download or **delete** any Drive-backed file by id,
  bypassing `secure_files` RLS structurally, because those bytes never pass through Postgres. Not
  an incident: 0 of 5 `secure_files` rows are Drive-backed today, so this closes a latent hole
  before that path carries data. Contract note: the lookup matches **`secure_files.id`** first,
  because `addGoogleDriveLink()` inserts the Drive id as the row's primary key and never populates
  the nominal `gdrive_file_id` column — that column is empty in every row. Callers must also delete
  the Drive blob **before** the `secure_files` row; reversing it makes the id unresolvable, the
  check fails closed, and the blob is orphaned in Drive rather than deleted.

- **2026-08-01** · `a6700cf` · fix(security): require group membership for drive-proxy download and delete

- **2026-07-30** · `7cda72f` · fix(audit): stop logging group events for groups the user has left
  — why: two things worth knowing before you touch audit logging or chase this error again.
  First, `20260707030000_restore_community_rpcs.sql` in this repo is **stale**: its header claims the
  community RPCs were never applied to the live project, but both functions exist there (recorded as
  `20260706223526`) and auto-join works. Do not re-apply it expecting to fix "Not a member of the
  study group" — the real cause is `RecentlySavedItem.destinationId`, persisted in SharedPreferences,
  naming a group the user has since left. Second, `logEvent` now fails **open**: if the membership
  lookup fails it still attempts the write. Keep it that way — the RPC is the enforcement point, and
  a client-side gate that fails closed would silently drop security audit records on a flaky network.
  Adds `20260730162359_enable_realtime_user_risk_state` (applied live): any table `watch*` subscribes
  to must be in the `supabase_realtime` publication, and needs `REPLICA IDENTITY FULL` if a column
  filter must survive DELETE.

- **2026-07-30** · `6f61e02` · fix: four runtime errors caught via logcat/VM-service monitoring
  — why: all four were invisible to `flutter logs`/logcat. Android Studio launches this app with
  `--dart-define=flutter.inspector.structuredErrors=true`, which routes framework exceptions to the
  Dart VM service `Extension` stream *instead of* stdout, so nothing reached the Android log at all.
  If you are hunting a runtime bug here, attach to the VM service (or `flutter run` without that
  flag) — a clean logcat does not mean a clean app. The deep-link fix also establishes that
  `supabase_flutter` owns the `login-callback` deep link; do not call `getSessionFromUrl` alongside
  it, the PKCE code is single-use and whichever handler loses the race reports a spurious auth
  failure on a login that succeeded.

- **2026-07-25** · `6015dc3` · chore(release): bump to 1.3.0+10

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
