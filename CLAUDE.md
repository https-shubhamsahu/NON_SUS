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

- `.github/workflows/gh-pages.yml`: on push to `main` — analyze, build web, deploy to GitHub Pages. It writes `nosus.foo` into `build/web/CNAME`; the deploy action's `cname` input does nothing on the pinned version, so keep that step.
- `.github/workflows/play-store-release.yml`: on `v*.*.*` tags — builds a signed AAB (keystore comes from `ANDROID_KEYSTORE_BASE64` secret; without `android/key.properties` the Gradle config silently falls back to debug signing), publishes a GitHub Release with the APK (what `releases/latest` download buttons serve), then uploads to Play internal track. After tagging, also bump the `app_latest_version` row in `remote_configs` — it drives the in-app update banner (`lib/features/config/presentation/providers/app_update_provider.dart`).

## Architecture

**State management:** Riverpod 3 (`flutter_riverpod`). Entry point `lib/main.dart` wires Supabase init, deep-link handling (`app_links`), and a `PageView` tab shell — in order: Workspace, Vault, Study Desk, Audit Log, Groups (`lib/components/floating_nav.dart` defines the labels/icons; `activeTabProvider` drives the index). Profile is not a tab — it's pushed as a route from the avatar button in the header.

**Feature-first layout:** `lib/features/<feature>/` with `data/` (clients, repositories), `domain/` (entities), `presentation/` (screens, widgets, providers). Older features (e.g. `groups`) are flatter (`screens/`, `widgets/`, `providers/` at feature root) — match whichever style the feature you're editing uses. Access data only through repositories from presentation code — don't call Supabase clients directly from widgets in Clean-Architecture features.

**Cross-cutting layers:**
- `lib/services/`: singletons — `supabase_service.dart`, `audit_service.dart`, `screenshot_guard.dart`, `device_integrity_service.dart`, `risk_engine_service.dart`, `web_security_guard.dart`, `burn_file_crypto.dart`
- `lib/core/`: Supabase bootstrap + providers (`core/supabase/`), theme provider, mascot (Rive), utils
- `lib/config/`: `supabase_credentials.dart` (leave both fields empty → app runs in mock fallback mode with no backend), `fhe_config.dart` (FHE feature flags), `storage_router_config.dart`

**Backend:** everything goes through Supabase — auth, storage, Postgres (schema history in `supabase/migrations/`, heavy RLS use), and Edge Functions for anything secret-touching (burn files, share fetch/heartbeat, FHE proxy). Client-side crypto (AES via `encrypt`) is used for burn notes/files; keys travel in URL fragments, never to the server.

**Deep-link URL contract:** `extractBurnNoteToken` / `extractBurnFileToken` in `lib/main.dart` are public and covered by `test/unit/deep_link_parsing_test.dart`. Burn links are already shared into the wild — silently changing what parses is a production outage. Keep legacy formats parsing.

**Mascots (Lux/Nox):** two Rive-driven characters (`assets/mascot/*.riv`) that react to app state — see `MASCOT_GUIDE.md` for the full mood table. Driven imperatively via Riverpod, e.g. `ref.read(luxMascotProvider.notifier).play(MascotMood.lookAround)`. Never let a mascot occupy content space; respect `MediaQuery.disableAnimations` (locks to `MascotMood.idle`).

**Product rules (`PROJECT_CONSTITUTION.md` is the authoritative source):**
- Copy/marketing must never outrun the actual cryptography — e.g. don't claim screenshot-proofing in a browser (impossible) or "the server cannot see it" ahead of what's actually implemented.
- No v2/v3 duplicate files or parallel branch iterations of the same feature — edit in place.
- Every new table gets RLS; SQL migrations are incremental and idempotent, never edited after landing.

## FHE subsystem guardrails

(From `.cursor/rules/no-sus-fhe.mdc`; applies to `lib/features/fhe/`, `lib/config/fhe_config.dart`, `services/fhe-compute/`, `supabase/functions/fhe-proxy/`. Full context in `services/fhe-compute/NEXT_SESSION.md` and `INTEGRATION_GUIDE.md`. `SHIELD.md` documents the (shelved) architecture that reuses this same FHE spine: `lib/features/sealed/`, `supabase/functions/{sealed-api,pact-matcher}` — kept in the repo but not the active product, per `PROJECT_CONSTITUTION.md` §4.)

- **Additive only.** Never modify existing AES storage, upload/download, sharing, viewing, auth, or existing Supabase objects. FHE is for encrypted *computation*; AES stays responsible for storage.
- **Off by default.** Every capability sits behind a granular flag in `lib/config/fhe_config.dart`; never add a single global FHE switch.
- **Flutter never talks to TFHE directly.** Traffic path: app → `FheTransport` → `fhe-proxy` Edge Function → Rust `fhe-compute`.
- **Never log or persist** plaintext, ciphertext, key material, or key fingerprints. Supabase stores metadata only; private keys never leave RAM/device.
- Keep the crypto backend behind the `FheCryptosystem` trait so other engines can be swapped in.
- Before claiming FHE work done: `cargo build && cargo test` in `services/fhe-compute` AND `flutter analyze` at repo root, both clean.
