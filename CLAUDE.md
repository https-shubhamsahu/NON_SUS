# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

**NO SUS** — a secure study-group workspace (file sharing, watermarking, burn notes/files, audit logging) built with Flutter on a Supabase backend. Ships to web (GitHub Pages at `nosus.foo`) and Android (Play Store). Four sub-projects live in this repo:

- Root: the Flutter app (`lib/`, `test/`, `android/`, `web/`)
- `supabase/`: Postgres migrations + Deno Edge Functions (`supabase/functions/*` — e.g. `fhe-proxy`, `burn-file-*`, `share-fetch`, `sealed-api`)
- `services/fhe-compute/`: isolated Rust (TFHE-rs) homomorphic-compute service
- `homepage/`: Next.js marketing landing page, statically exported (`output: "export"`), served at the **`nosus.foo` root**. The Flutter web app moved to **`app.nosus.foo`** (deployed to a separate `nosus-app` repo). `.github/workflows/gh-pages.yml` has two independent jobs: `landing` (this repo's gh-pages) and `app` (needs `APP_DEPLOY_TOKEN`). A pre-paint shim in `homepage/src/app/layout.tsx` forwards legacy `nosus.foo/#/burn|burnfile|v|join/…` links and Supabase auth callbacks to the app subdomain (fragment preserved — the AES key lives there). The hero has REAL working Burn Note/File tools; their WebCrypto (`homepage/src/lib/burnCrypto.ts`) is kept byte-compatible with the Dart app by `test/unit/burn_crypto_web_compat_test.dart` — never change one side without the other. Cross-product URLs + dev identity live in `homepage/src/lib/links.ts`. It has its own `CLAUDE.md`/`AGENTS.md`; the vendored Next.js has breaking changes, so read `homepage/node_modules/next/dist/docs/` before writing code there. Keep its content honest: no invented testimonials, usage stats, or APIs that don't exist.

## Commands

```sh
flutter pub get
flutter analyze                      # must be clean before claiming a task done
flutter test                         # all tests
flutter test test/unit/deep_link_parsing_test.dart   # single test file
flutter build web --base-href "/"    # web release (CI adds --dart-define-from-file=.env)
```

**This Windows machine:** the `flutter` on PATH (`C:\Users\shubh\flutter\bin`) is an EMPTY checkout — the real SDK is `C:\Users\shubh\AppData\Local\flutter\bin\flutter.bat` (stable 3.44.4, matching CI).

**Rust service** (`services/fhe-compute/`): `cargo build && cargo test`. Toolchain is scoop-installed `stable-x86_64-pc-windows-gnu` (no MSVC); needs scoop gcc + cargo on PATH:
`export PATH="/c/Users/shubh/scoop/apps/gcc/current/bin:/c/Users/shubh/.cargo/bin:/c/Users/shubh/scoop/persist/rustup/.cargo/bin:/c/Users/shubh/scoop/shims:$PATH"`
Real-crypto test suites are slow (~14 min). The gnu-linker workaround lives in `services/fhe-compute/.cargo/config.toml` — don't remove it.

**Previewing web builds:** use the Browser pane with `.claude/launch.json` servers — `web-release-static` serves `build/web` on :5051 (build first).

## CI

- `.github/workflows/gh-pages.yml`: on push to `main` — analyze, test, build web, deploy to GitHub Pages. It writes `nosus.foo` into `build/web/CNAME`; the deploy action's `cname` input does nothing on the pinned version, so keep that step.
- `.github/workflows/play-store-release.yml`: on `v*.*.*` tags — analyzes, **runs `flutter test`** (release-gating — a broken test suite now blocks the build, not just local dev), builds a signed AAB (keystore comes from `ANDROID_KEYSTORE_BASE64` secret; without `android/key.properties` the Gradle config silently falls back to debug signing), publishes a GitHub Release with the APK (what `releases/latest` download buttons serve), then uploads to Play internal track. After tagging, also bump the `app_latest_version` row in `remote_configs` — it drives the in-app update banner (`lib/features/config/presentation/providers/app_update_provider.dart`). Paste-ready Play Console listing copy + data-safety answers live in `store_listing/` — every claim there must map to a shipped feature. Both workflows use `subosito/flutter-action`'s `cache: true` and write a `SENTRY_DSN` line into `.env` (empty/no-op unless that secret is ever set — see crash reporting below).

## Architecture

**State management:** Riverpod 3 (`flutter_riverpod`). Entry point `lib/main.dart` wires Supabase init, deep-link handling (`app_links`), and a `PageView` tab shell — in order: Workspace, Vault, Study Desk, Audit Log, Groups (`lib/components/floating_nav.dart` defines the labels/icons; `activeTabProvider` drives the index). Profile is not a tab — it's pushed as a route from the avatar button in the header.

**Feature-first layout:** `lib/features/<feature>/` with `data/` (clients, repositories), `domain/` (entities), `presentation/` (screens, widgets, providers). Older features (e.g. `groups`) are flatter (`screens/`, `widgets/`, `providers/` at feature root) — match whichever style the feature you're editing uses. Access data only through repositories from presentation code — don't call Supabase clients directly from widgets in Clean-Architecture features.

**Cross-cutting layers:**
- `lib/services/`: singletons — `supabase_service.dart`, `audit_service.dart`, `screenshot_guard.dart`, `device_integrity_service.dart`, `risk_engine_service.dart`, `web_security_guard.dart`, `burn_file_crypto.dart`
- `lib/core/`: Supabase bootstrap + providers (`core/supabase/`), theme provider, mascot (Rive), utils
- `lib/config/`: `supabase_credentials.dart` (leave both fields empty → app runs in mock fallback mode with no backend), `fhe_config.dart` (FHE feature flags), `storage_router_config.dart`

**Backend:** everything goes through Supabase — auth, storage, Postgres (schema history in `supabase/migrations/`, heavy RLS use), and Edge Functions for anything secret-touching (burn files, share fetch/heartbeat, FHE proxy). Client-side crypto (AES via `encrypt`) is used for burn notes/files; keys travel in URL fragments, never to the server.

**Deep-link URL contract:** `extractBurnNoteToken` / `extractBurnFileToken` / `extractBurnFilesToken` in `lib/main.dart` are public and covered by `test/unit/deep_link_parsing_test.dart`. Burn links are already shared into the wild — silently changing what parses is a production outage. Keep legacy formats parsing.

**Burn Files: single vs. multi-file share.** `#/burnfile/<id>?k=&v=` (singular) is the original one-file link, untouched. `#/burnfiles/<id1,id2,...>?k=<key1,key2,...>&v=<iv1,iv2,...>` (plural) is an additive multi-file link — same per-file AES-CBC crypto as always (each file keeps its own independent key/IV; no new crypto primitive), just N of them joined by commas. `BurnFileViewerScreen` takes `List<({String id, String keyHex, String ivHex})> files` (a record type, not a class, to avoid a feature-screen → `main.dart` import) and handles both shapes identically — a single-file share is just a one-element list. The creator (`burn_file_creator_screen.dart`) runs every file's encrypt→init→upload→confirm pipeline **in parallel** via `Future.wait`, with AES encryption offloaded to a `compute()` isolate — that parallelism, not any server change, is what makes multi-file shares fast. A share is capped at **25MB combined** (`_maxTotalBytes` in the creator, checked client-side before any upload starts) and 10 files (`_maxFilesPerShare`); the per-file ceiling is enforced authoritatively server-side via the live-tunable `remote_configs.burn_files_max_size_bytes` row (both `burn-file-init` and `burn-file-confirm` read it dynamically — changing that one row, no code deploy, is how the cap itself is tuned). Redemption codes (`create-redemption-code`/`redeem-code`) stay single-target only — a multi-file share only gets the link, never a short code. The homepage's own burn-file tool (`homepage/src/components/BurnTool.tsx`) is deliberately still single-file-only; only its size-cap constant (`FILE_MAX_BYTES` in `burnApi.ts`) was kept in sync at 25MB.

**App id / custom scheme:** `foo.nosus.app` (reverse-DNS of `app.nosus.foo`) is both the Android applicationId and the custom URL scheme (`foo.nosus.app://v/…`, `://open`, `://join/…`). It must stay identical everywhere it appears: `android/app/build.gradle.kts`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/main.dart`, `lib/features/share/.../anonymous_share_viewer_screen.dart`, `homepage/src/lib/appLaunch.ts`, and the `packageName` in `play-store-release.yml`. The OAuth callback scheme `io.supabase.nosus` is intentionally different (it's registered with Supabase auth) — do not "fix" it to match.

**Riverpod rebuild scoping:** `StudyGroup`/`GroupMember` (`lib/features/groups/domain/models/study_group.dart`) have explicit `==`/`hashCode` — added specifically so `group_detail_screen.dart` can `ref.watch(groupsProvider.select(...))` down to just its one group instead of rebuilding the whole screen whenever *any* group changes. Don't drop that equality override without checking that call site; without it `.select()` silently stops working (every list emission produces new object instances that compare unequal by identity, so the "optimization" becomes a no-op, not a crash — easy to miss).

**Mascots (Lux/Nox):** two Rive-driven characters (`assets/mascot/*.riv`) that react to app state — see `MASCOT_GUIDE.md` for the full mood table. Driven imperatively via Riverpod, e.g. `ref.read(luxMascotProvider.notifier).play(MascotMood.lookAround)`. Never let a mascot occupy content space; respect `MediaQuery.disableAnimations` (locks to `MascotMood.idle`).

**Product rules (`PROJECT_CONSTITUTION.md` is the authoritative source):**
- Copy/marketing must never outrun the actual cryptography — e.g. don't claim screenshot-proofing in a browser (impossible) or "the server cannot see it" ahead of what's actually implemented.
- No v2/v3 duplicate files or parallel branch iterations of the same feature — edit in place.
- Every new table gets RLS; SQL migrations are incremental and idempotent, never edited after landing.

**Burn Notes rate limiting:** unlike Burn Files (edge-function-fronted, real per-IP-hash counter), Burn Notes insert directly from the client into `burn_notes` — no edge-function hop, by design, for speed. `check_burn_note_velocity()` (trigger on `burn_notes`, added in `20260721000000_security_hardening_and_burn_note_rate_limit.sql`) is a coarse, IP-blind global circuit breaker (>120 inserts/minute globally → reject), not a per-client limit — Supabase's connection pooler means a real per-IP limit here would need routing through an edge function, which was a deliberate trade-off *not* taken to keep the direct-insert path fast. Don't "fix" this into a full rate limiter without re-checking whether that speed trade-off still holds.

**Known accepted advisor finding:** `pg_net` lives in the `public` schema (Supabase security advisor: `extension_in_public`). `ALTER EXTENSION pg_net SET SCHEMA` is unsupported by that extension — the only real fix is drop+recreate, which risks cascading into anything using `net.http_post`. Left as-is; don't attempt the move without checking every `net.http_post` call site first.

**Accessibility:** custom tappable widgets (`GestureDetector`/`InkWell` standing in for a button) need an explicit `Semantics(button: true, label: '...', child: ...)` wrapper — Flutter gives none of that for free on a bare `GestureDetector`. The highest-traffic surfaces (bottom nav, auth screens, burn creator/viewer, groups) already follow this; `test/widget/auth_screen_test.dart` and `groups_screen_test.dart` have regression tests checking specific `Semantics` widgets' `properties.label`/`properties.button` directly (more reliable in this codebase than `find.bySemanticsLabel` + the rendered semantics tree, which didn't reliably resolve during testing). Icon-only tap targets should generally just be `IconButton` (48dp minimum + tooltip-as-label for free) rather than a hand-wrapped `GestureDetector`+`Icon`. A meaningful chunk of lower-traffic screens (onboarding, `upload_modal.dart`, `save_to_no_sus_dialog.dart`, `profile_screen.dart` secondary actions, `empty_states.dart`) still need the same treatment — not yet done.

**Crash reporting (Sentry):** `lib/config/crash_reporting_config.dart` — off by default (`SENTRY_DSN` empty). Wired into `FlutterError.onError` and the `runZonedGuarded` error handler in `lib/main.dart` via the low-level `SentryFlutter.init(configure)` call (no `appRunner:` — kept out of the existing bootstrap sequence deliberately). `sendDefaultPii = false` and tracing stays at 0% always — this product's whole premise is zero-knowledge/no-tracking, so don't casually raise either without reading `store_listing/data_safety_answers.md`'s note on this first (enabling it flips a Data Safety answer from "not collected" to "collected").

**Play Integrity — scaffolded, not enabled.** `AppIntegrityConfig.enabled` (default false) gates `lib/services/play_integrity_service.dart`, which calls native `PlayIntegrityManager.kt` (`android/app/.../security/`, registered as the `co.nosus.app/play_integrity` MethodChannel in `MainActivity.kt`) and forwards the token to the deployed-but-unconfigured `verify-play-integrity` edge function. This is real, structurally-correct code (the edge function reuses `drive-proxy/index.ts`'s proven Google-service-account JWT pattern) but **has never been exercised against a real device-generated token** — no real device/Play-linked build was available to test with. Three things block it from actually working: `PlayIntegrityManager.kt`'s `cloudProjectNumber` is `0` (fails fast on purpose), the edge function's `PLAY_INTEGRITY_SERVICE_ACCOUNT_EMAIL`/`PLAY_INTEGRITY_PRIVATE_KEY` secrets aren't set (don't assume `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — used for Play publishing — has Play Integrity API scope; this needs its own service account, same convention as `drive-proxy`'s `GD_SERVICE_ACCOUNT_EMAIL`), and `AppIntegrityConfig.enabled` is false. All three docs are cross-referenced in the code itself — read `AppIntegrityConfig`'s doc comment before enabling anything.

## FHE subsystem guardrails

See `.claude/rules/no-sus-fhe.md` — loads automatically when touching FHE-related files.
