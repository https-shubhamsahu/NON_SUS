# PROJECT_HANDOVER.md — Single Source of Truth

> **Read this first.** This file supersedes the old `AI_HANDOVER.md` (deleted) and is the
> authoritative handover. `README.md` / `AGENTS.md` are secondary. Any future AI or developer
> should be able to continue development from this file + the repository alone. Keep it in sync
> after **every** coding session (see [Daily Workflow](#daily-workflow)).
>
> **Status (2026-07-05, updated):** **NO SUS is now SecureSend** — a secure document-link
> product (send a file as a tracked, watermarked link; the recipient views it in a browser with
> NO account required). This supersedes the earlier "pivot to Sealed" direction below.
> **Sealed is shelved, not deleted**: it is fully built (M0–M2, see its own section), tested, and
> live-verified on the Supabase project — kept as a proven asset for a possible future pivot, but
> it is NOT the active product. Do not build further Sealed milestones (M3+) without an explicit
> founder decision to un-shelve it.

---

## Current Product: SecureSend

**Send a document as a link. The recipient views it — with or without a NO SUS account — but the
document is watermarked to their identity, blurred until touched, and every view is logged.**

This reuses the existing in-app secure-viewer stack (watermark + blur-until-touch, built for
signed-in group members) and adds exactly one new capability: an anonymous, tracked, revocable
access path for people who have no account at all.

### Architecture

```
Sender (signed in)                     Recipient (no account needed)
  file_card.dart "Share Link"            opens https://host/#/v/<token> in ANY browser
        │                                        │
        ▼                                        ▼
  share_links INSERT (RLS: file owner only) main.dart boot fork (before Supabase/auth init)
        │                                        │
        │                                        ▼
        │                              AnonymousShareViewerScreen
        │                                 (email gate — becomes the watermark identity)
        │                                        │
        │                                        ▼
        │                              share-fetch Edge Function (verify_jwt: false)
        │                                 validates token (service role) → logs view →
        │                                 mints a 5-min Storage signed URL
        │                                        │
        │                                        ▼
        │                              http.get(signed_url) → bytes
        │                                        │
        │                                        ▼
        └──────────────────────────► SecureDocumentViewer + WatermarkConfig(email: entered)
                                        (same widget the in-app viewer uses)
```

### Key files
- Migration: `supabase/migrations/20260705020000_securesend_share_links.sql` — `share_links`
  (token, file_id, created_by, revoked, expires_at, max_views, view_count) + `share_link_views`
  (append-only view log). RLS: only the file's **owner** may create a link
  (`share_links_insert_owner`); only the creator may read/revoke their own links; no policy
  grants public SELECT on the token — resolution happens only through `share-fetch`.
- Edge function: `supabase/functions/share-fetch/index.ts` — public (`verify_jwt: false`, same
  trust model already used by this project's `drive-proxy`). Takes `{token, viewer_email}` →
  validates not-revoked/not-expired/under-view-limit → logs the view + bumps `view_count` →
  mints a Storage signed URL (service role) → returns `{file_name, type, signed_url}`.
  GDrive-linked files are explicitly rejected (out of scope for v1).
- Flutter feature: `lib/features/share/{domain,data,presentation}` — `ShareRepository`
  (authenticated create/list/revoke via direct RLS-scoped Supabase calls) and
  `ShareFetchClient` (a deliberately separate, always-anonymous HTTP client — no Supabase
  session, ever, since a recipient may have none). `ShareLinkDialog` wires "Share Link" into
  `file_card.dart`'s popup menu. `AnonymousShareViewerScreen` is a **plain `StatefulWidget`**
  (not `ConsumerWidget`) with its own `MaterialApp` — a fully standalone entrypoint.
- Boot fork: `lib/main.dart`'s `_extractShareToken(Uri.base)` runs **before** any Supabase/auth
  initialization. If the URL matches `/v/<token>` (checks both hash fragment and path, so it
  works regardless of URL strategy), `runApp(AnonymousShareViewerScreen(token))` fires directly
  and the function returns — the normal app, Supabase init, and `AuthGate` are never touched for
  this path.

### Honesty rule (load-bearing — put in all copy)
**Screenshot-blocking is impossible in a browser.** The anonymous web view's protection is
watermark-with-identity + blur-until-touch + view logging — deterrence and attribution, not a
hard block. The Android app's `FLAG_SECURE` hard block only applies to users who have the
installed app. `AnonymousShareViewerScreen`'s copy already says "watermarked · view logged," never
"screenshot-proof" — keep it that way in any future copy changes.

### Verified this session
- `flutter analyze`: clean project-wide (only 2 pre-existing unrelated info-lints in `sealed/`).
- `share-fetch` deployed live; smoke-tested with an invalid token → correct `404 "This link is
  invalid"` (confirms the function boots, authenticates via service role, and fails closed).
- **Rollback-protected RLS test on live Postgres** (real owner/non-owner users, zero rows
  persisted): a non-owner's INSERT into `share_links` for someone else's file is **rejected**; a
  non-owner cannot SELECT another user's `share_links` row; the owner CAN select/update
  (revoke) their own row. This is the core trust boundary and it holds.
- **NOT verified interactively in-browser this session** — see "Known limitation" below.

### Known limitation: interactive browser verification blocked by the preview harness
Extensive investigation (documented so it isn't repeated): the sandboxed preview browser used in
this session never renders ANY Flutter web build (debug or release) — `main.dart.js` and
`canvaskit.wasm`/`.js` all fetch successfully (200 OK, confirmed via network inspection),
`window._flutter.loader` initializes correctly, WebGL is available, but the Dart entrypoint's
`main()` never executes (confirmed via temporary diagnostic `print()` calls placed at the very
first line of `main()` — even that never fired). This points to the CanvasKit/WASM engine
bootstrap hanging specifically inside this harness's browser, not a defect in app code — likely a
sandboxing/resource constraint on WASM instantiation. This Flutter version has no HTML-renderer
fallback to route around it (`flutter build web --help` shows no `--web-renderer` flag anymore).
**Action for a human:** open `build/web` (already built) in a real browser to confirm visually —
e.g. `python -m http.server 5051 --directory build/web` then open `http://localhost:5051`, or
`flutter run -d chrome --dart-define-from-file=.env`. A `.claude/launch.json` config
(`web-release-static`) already serves `build/web` on port 5051 for this purpose.

### Explicitly out of scope for v1 (say so, don't silently drop)
- GDrive-linked files (only Supabase-Storage-backed `secure_files` rows are shareable).
- Native deep-link handoff into the installed app (the web link works everywhere regardless).
- Per-view IP capture (email + timestamp is enough tracking for v1).
- A "manage my links" UI (revoke exists in the repository/RLS layer; no screen surfaces it yet).

---

## Sealed (SHELVED — fully built, not the active product)

**Sealed lets people privately express an intent toward a specific person — romantic, platonic,
professional, or reconnection — that is revealed only if it is mutual.** A non-mutual signal is
never exposed. The reveal is computed over ciphertext by an existing FHE mutual-match primitive,
so the platform's trust story is cryptographic, not policy-based.

**This is not currently being built on.** It is preserved below exactly as documented when active,
for a possible future pivot back. M0 (foundation), M1 (seal flow), and M2 (pact-matcher) are
complete and were live-tested this same session (RLS proven, matcher gap closed, auth hardened).

Why it can grow with zero marketing budget: **to learn if someone reciprocates, you must invite
them** → the product recruits its own users (built-in viral loop). This is the deliberate answer
to the founder's constraint of *no distribution, no budget, solo*.

FHE is **invisible infrastructure**, not the pitch. See [Honesty Rule](#honesty-rule-load-bearing).

**Legacy vision (NO SUS, being retired):** absolute accountability for shared study documents via
immutable audit logs, watermarking, and anti-screenshot controls. The secure-viewer stack is kept
dormant as an optional **SecureSend** revenue hedge — do not delete it during the pivot.

## Product Goals

- **Short term:** ship the Sealed core loop (seal → invite → mutual reveal) web-first; validate
  K-factor and next-day return in one seeded community.
- **Medium term:** Someday List (non-expiring seals that resurface), safety/moderation,
  subscription monetization, professional vertical ("Silent Signals").
- **Long term:** the universal *intent graph* + AI copilots + on-device/threshold crypto so the
  "the server literally cannot see it" claim becomes literally true; expand across verticals.

## Current Progress

**Done (reusable spine):**
- Flutter app (Android/iOS/web-capable, ~20k LOC, Riverpod, Material 3 monochrome theme).
- Supabase backend: 10 tables, RLS on all, RPCs, audit hash-chain, storage bucket, realtime.
- Auth: email/password, magic link, phone OTP; deep links `io.supabase.nosus://login-callback`.
- **FHE subsystem (crown jewel):** Rust TFHE-rs microservice (~4.3k LOC, tested), including the
  **mutual-match primitive** `homomorphic_mutual_match` — the entire crypto+transport spine for
  Sealed already works: Rust `/pact/evaluate` → `fhe-proxy` action `pact_evaluate` → Flutter
  `FheTransport`.
- Edge functions: `fhe-proxy`, `drive-proxy`, `storage-router`, `account-manager`.

**Partial:**
- FHE key lifecycle (rotate/revoke wired; expiry sweep not enforced) — see
  `services/fhe-compute/NEXT_SESSION.md`.
- Async worker writeback to `fhe_compute_jobs` (terminal states only; untested vs live Supabase).
- Multi-cloud storage router (designed, flag-gated, `FREE_STORAGE_STRATEGY.md`).

**Remaining (the Sealed build):** everything in [Roadmap](#roadmap-m0m10) M0–M10.

## Folder Structure

```
lib/
  main.dart                     app shell, 5-tab floating nav, entry point
  theme.dart                    NoSusTheme — Material 3 monochrome tokens
  config/                       supabase_credentials, fhe_config (flags), storage_router_config
  core/                         constants, providers (theme), supabase bootstrap, utils (debugLog)
  services/                     singletons: supabase_service, audit_service, focus_service,
                                screenshot_guard, share_intent_service
  components/                   secure_viewer/ (watermark + touch-reveal), spyglass_viewer, nav
  features/
    auth/        groups/  files/     Clean Architecture (domain/data/presentation) — REUSE auth
    fhe/                             FHE client: transport, engine, key_manager, providers, demo
    audit/ focus/ notes/ onboarding/ profile/ vault/ workspace/   service-based features
    sealed/      <-- NEW (to build): domain/data/presentation for the Sealed product
services/fhe-compute/            Rust TFHE-rs microservice (see its own src/ tree)
supabase/
  migrations/                    baseline + fhe_replay_protection + fhe_subsystem + storage_router
  functions/                     fhe-proxy, drive-proxy, storage-router, account-manager
demo_documents/                  synthetic research PDFs (legacy demo; retire with pivot)
test/                            flutter_test + mocktail
```

## Architecture

- **Frontend:** Flutter + Riverpod. Hybrid: Clean Architecture (`auth`, `groups`, `files`);
  service-singleton for the rest. New `sealed` feature follows Clean Architecture.
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions + Realtime).
- **Auth flow:** Supabase Auth → `handle_new_user` trigger creates `profiles` row (**and, legacy,
  auto-joins "Global Community" + "TSEC, Kandivali" groups — this trigger must change for Sealed**).
- **FHE spine (reused for Sealed):**
  `Flutter FheTransport → Supabase fhe-proxy (JWT auth + replay protection + tenant isolation +
  event ledger) → Rust TFHE-rs service → encrypted result`. App never sees the service URL/token
  or any key material.
- **Storage:** private `secure-files` bucket (Cloudflare R2 backend in prod); Google Drive proxy;
  optional multi-cloud router (flag-gated).
- **Notifications / Analytics / Caching:** none yet (Realtime is used for live job/reveal updates).
  Sealed adds email (Resend) + FCM/APNs at M9.
- **Security:** RLS everywhere; audit hash-chains; Android `FLAG_SECURE`; watermarks; touch-reveal
  blur. See [Security](#security).
- **Deployment:** Flutter build (APK/AAB/web); Rust service on a container host; Supabase migrations
  + edge-function deploys. See [Deployment](#deployment).

## Database

RLS is **enabled on every table**. Legacy tables (retire/repurpose during pivot) + FHE tables:

**Legacy (`20260629000000_baseline.sql`):**
- `profiles` — user metadata (id=auth.uid, email, display_name, avatar, onboarding, survey_*).
- `study_groups` — group namespaces (id text, name, invite_code, is_watermark_enabled, file_count).
- `study_group_members` — (group_id, user_id, is_admin) PK.
- `secure_files` — file metadata (group_id, name, type, size, storage_path, gdrive_file_id,
  owner_id, security_status ∈ secured/pending/compromised/revoked).
- `audit_logs` — hash-chained ledger (previous_hash, entry_hash=SHA256(actor+event+created+prev));
  insert only via RPC `log_group_event`; verify via `verify_audit_chain`; strict `event_type` CHECK.
- `focus_logs` — (user_id, date, focus_minutes) study timer.
- `user_notes` — one scratchpad per user.
- **RPCs:** `is_group_member`, `is_group_admin` (SECURITY DEFINER, anti-recursion), `handle_new_user`,
  `update_study_group_file_count`, `audit_logs_hash_trigger`, `verify_audit_chain`, `log_group_event`,
  `create_study_group_with_creator`, `join_group_by_invite_code`, `join_public_group_by_name`,
  `ensure_community_exists`, `can_access_storage_object`, `can_delete_storage_object`.
- **Storage:** bucket `secure-files` (private, 25 MB limit, pdf/image mimetypes) + 4 object policies.
- **Realtime:** study_groups, study_group_members, secure_files, audit_logs, focus_logs, user_notes.

**FHE subsystem (`20260704000000_fhe_subsystem.sql`) — additive, metadata only, never key material:**
- `fhe_key_metadata` — fingerprints + lifecycle (status ∈ active/rotated/revoked/expired). RLS: own.
- `fhe_compute_jobs` — async job mirror (status, progress, result_ciphertext, attempts). RLS: own
  select/insert/cancel; worker uses service_role. Realtime-published.
- `fhe_events` — append-only ledger (event_type CHECK-listed; no UPDATE/DELETE policy). RLS: own read.
- `20260701000000_fhe_replay_protection.sql` — `fhe_nonces` (replay guard).
- `20260704105829_storage_router.sql` — `storage_objects` index for multi-cloud.

**Future migration (to build — M0):** `sealed_core.sql` — `sealed_profiles` (handle, contact_hash,
age_ok), `arenas` (intent_kind, key fingerprint), `arena_members` (arena_public_id u32), `seals`
(sealed_choice ciphertext, intent_kind, never_expires, status; **RLS: sealer sees only own; the
counterparty seal is never selectable**), `matches` (visible to both parties), `invites` (viral
loop). Later: `subscriptions`, `blocks`, `reports`, `recruiter_seats`, `agent_suggestions`.

## API Documentation

**FHE Edge Function `fhe-proxy`** — single bridge; POST envelope `{action, nonce, request_id,
timestamp, payload}`; requires Supabase JWT; enforces 5-min replay window + nonce single-use;
forwards to Rust with `X-Tenant-Id=user_id`. Actions → Rust paths:
`generate_keys|rotate_keys|revoke_keys /keys/*`, `encrypt /encrypt`, `decrypt /decrypt`,
`compute /compute`, `submit_job /jobs`, `compare /compare`, `mux /mux`, `similarity /similarity`,
**`pact_evaluate /pact/evaluate`**, `memory_search /memory/search`, `policy_evaluate /policy/evaluate`.
Response: `{request_id, job_id, result}`. Auth errors 401; replay 409; upstream failure 502.

**Rust service (behind proxy; bearer `FHE_SERVICE_TOKEN`):** routes in
`services/fhe-compute/src/api/mod.rs`. Key one for Sealed: **`POST /pact/evaluate`** with
`PactEvaluateRequest {arena_id, a_choice(b64 ct), a_id(u32), b_choice(b64 ct), b_id(u32)}` →
base64 encrypted `FheBool` that is true iff both picked each other. Evaluator:
`services/fhe-compute/src/compute/pact.rs::homomorphic_mutual_match`.

**Other edge functions:** `drive-proxy` (Google Drive service-account), `storage-router`
(multi-cloud S3), `account-manager`.

**To build (M2):** `pact-matcher` edge function — on new seal, find counter-seal → ensure arena →
`pact_evaluate` → `decrypt` → on true, insert `matches` + notify.

## AI Documentation

**Current:** `lib/features/fhe/data/ai_summary_service.dart` — legacy research-summary (deterministic
fallback; retire with pivot). No production LLM wired.

**Planned (M8, flagged, additive — core works without it):** (1) icebreaker generation on match,
(2) "who to seal" suggestions from contacts/context, (3) connector "wingman" agent for pro intros.
Model: Claude (`claude-*`). AI runs **after** the privacy boundary — never receives a non-mutual
choice. If removed, the primitive still works (the honesty test AI must pass here).

## Features

- **Done:** auth portal, 5-tab nav, study groups, file upload/pin/download/delete, Drive linking,
  secure reader (touch-reveal + watermark), notepad, focus timer, audit views, FHE demo/lab.
- **In progress:** FHE key lifecycle, async worker writeback.
- **Planned:** Sealed M0–M10.
- **Cancelled/retiring:** research-document comparison, AI research-summary, study groups (as the
  primary surface).
- **Future ideas:** intent-graph API, dating/hiring/reconnection verticals, on-device FHE.

## Business Logic

- **Legacy:** group membership gates file access; audit logs are append-only + hash-chained + RPC-
  only; owners/admins control files; invite codes join groups.
- **Sealed:** a *seal* is a one-directional encrypted choice; a *match* exists only when the FHE
  predicate over both parties' seals decrypts true; **reveal is always free (never paywall consent)**;
  seals with `never_expires` persist and re-evaluate against future counter-seals (Someday List).

## Tech Stack

Flutter + Dart 3.12.1+ (one codebase → Android/iOS/web) · Riverpod 3 · Supabase (Postgres/Auth/
Storage/Edge/Realtime — generous free tier) · Rust + TFHE-rs (Zama) for FHE · Deno (edge functions).
Planned: Stripe + RevenueCat (billing), Resend + FCM/APNs (notifications), Claude API (AI).
**Why:** Flutter = one codebase all platforms (solo-founder leverage); Supabase = batteries-included
+ free; TFHE-rs = Rust-native, memory-safe, cheap Boolean ops fitting the tiny pact predicate.
**Alternatives considered:** Next.js web-only (faster web, loses native reuse); Firebase (weaker
Postgres/RLS); OpenFHE (heavier C++). Backend is abstracted so another FHE engine can slot in.

## Environment Variables

- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — client (via `.env`, `--dart-define-from-file`).
- Edge-function secrets (never in app): `FHE_COMPUTE_URL`, `FHE_SERVICE_TOKEN`,
  `SUPABASE_SERVICE_ROLE_KEY` (auto), Drive service-account creds, multi-cloud S3 keys.
- Flutter FHE flags (`--dart-define`, default off): `FHE_ENABLE_KEY_GENERATION`,
  `FHE_ENABLE_PRIVATE_MEMORY`, `FHE_ENABLE_POLICY_ENGINE`, `FHE_ENABLE_HOMOMORPHIC_SEARCH`,
  `FHE_ENABLE_BENCHMARKS`, `FHE_ENABLE_SELECTIVE_TRUTH`, plus **`enableSealed` (to add, M0)**;
  `FHE_USE_LOCAL_COMPUTE`, `FHE_LOCAL_COMPUTE_URL`, `FHE_LOCAL_SERVICE_TOKEN`.
- **Secrets are gitignored** (`.env*`, `*.key`, `*.pem`). Never hardcode.

## Dependencies

Key pub packages (see `pubspec.yaml`): `flutter_riverpod` (state), `supabase_flutter` (backend),
`app_links` (deep links — reused for invites), `file_picker`, `pdfrx` (PDF — legacy viewer),
`screen_protector` (Android FLAG_SECURE), `share_plus` (reused for invite sharing),
`google_fonts`, `flutter_animate`, `smooth_page_indicator`, `uuid`, `http`. Dev: `flutter_lints`,
`flutter_launcher_icons`, `mocktail`. `pdfrx`/`screen_protector` are legacy-viewer only — keep for
SecureSend hedge; removable if that hedge is abandoned.

## Known Bugs

| Bug | Severity | Fix |
|---|---|---|
| Theme resets on restart (SharedPreferences bootstrap timing) | Med | await prefs before first build |
| Phone OTP has no resend timer / rate-limit warning | Low | add cooldown UI |
| Android forced iOS bounce scroll physics | Low | platform-aware ScrollPhysics |
| Onboarding "skip" jumps past identity steps | Med | fix skip routing |
| Dead feedback submissions (success toast, no backend) | Low | wire or remove |
| Local-only notification prefs | Low | persist server-side |

## Technical Debt

Cosmetic "SECURED"/"Tap to Decrypt" badges (no real E2E yet); weak invite codes (modulo sequence —
brute-forceable); async worker writeback untested vs live Supabase; FHE key expiry not enforced;
legacy `handle_new_user` hardcodes specific groups. **Pivot debt:** remove study-group/research
surfaces cleanly at pivot time (not before).

## Performance

Bottlenecks are future: FHE compute at consumer scale (mitigate — the pact op is 2 eq + 1 AND;
evaluate lazily only when a counter-seal exists; move on-device at M10). Rust `target/` build is
~39 GB locally (gitignored). No app-level perf issues at current scale.

## Security

RLS on all tables; audit hash-chains (`verify_audit_chain`); replay protection (nonce + timestamp);
tenant isolation via `X-Tenant-Id`; no key material in Supabase (metadata only); no plaintext/
ciphertext/keys logged. **Sealed-critical:** `seals` RLS must make a counterparty's choice
unselectable by anyone; reveal only via the matcher after a true decrypt.

### Honesty Rule (LOAD-BEARING)

Until **M10**, the interim design holds the pact key server-side
(`services/fhe-compute/src/compute/pact.rs:23-26`). Therefore all copy/marketing says
**"encrypted, revealed only on mutual match"** — **NOT** "we mathematically cannot see it." The
stronger, brand-defining claim is only earned after M10 (on-device encryption + threshold/2-party
key). Do not let the brand outrun the crypto.

## Testing

Rust: `cd services/fhe-compute && cargo test` (incl. `tests/pact_test.rs`). Flutter: `flutter analyze`
(zero issues) + `flutter test` (mocktail). Missing/needed: Sealed matcher path tests, RLS negative
tests (counterparty seal unselectable), E2E two-account mutual-match. Toolchain per memory
`fhe-build-toolchain` (Rust via scoop rust-gnu; Flutter SDK in AppData).

## Deployment

1. `.env` with `SUPABASE_URL` + `SUPABASE_ANON_KEY`. 2. `flutter pub get`. 3. Supabase: apply
`supabase/migrations/*` in order; `supabase functions deploy fhe-proxy` (+ others); set edge secrets.
4. Rust: containerize `services/fhe-compute` (Dockerfile present); host on a cheap/free tier; set
`FHE_COMPUTE_URL`/`FHE_SERVICE_TOKEN`. 5. Flutter build: `flutter build web` (web-first launch) /
`apk`/`appbundle` with `--dart-define-from-file=.env` (+ `--dart-define=enableSealed=true` once M0).

## Daily Workflow

Branch off `pivot/sealed-foundation`. Before a feature: state plan + risks + edge cases here, then
build. After: self-review (bugs/security/perf), run analyze+tests, and **update this file**
(architecture, roadmap status, bugs, decisions, changelog). Never let docs drift from code.

## Coding Standards

Dart: camelCase vars, PascalCase classes, `const` widgets, `final` over `var`, typed exception
catches, `NoSusTheme` tokens, no hardcoded secrets, no `print` (use `debugLog`). Architecture:
Clean layers (domain→data→presentation) for new features; access data only via repositories; RLS on
every new table; one provider per model; no v2/v3 files; no dead code; idempotent migrations.

## Roadmap (M0–M10)

Big-bang Phase 1–4, executed in dependency order. Each milestone: Objective · Tasks · Files · DB ·
UI · Backend · AI · Testing · Acceptance · Complexity · Deps · Risk.

- **M0 Foundation** — *Obj:* schema + flag + scaffold. *Files:* `sealed_core.sql`, `fhe_config.dart`,
  `lib/features/sealed/**`. *DB:* arenas/arena_members/seals/matches/invites +RLS. *Testing:* migration
  applies, analyze/cargo green. *Accept:* tables + RLS exist, app builds. *Complexity:* M. *Deps:* —.
  *Risk:* Low.
- **M1 Seal flow** — handle onboarding, seal-toward-someone, arena assignment, `encrypt`, persist.
  *UI:* onboarding + seal screen. *Backend:* reuse FheTransport `encrypt`. *Accept:* a seal row is
  created with a ciphertext. *Complexity:* M. *Deps:* M0. *Risk:* Med (arena/key model).
- **M2 Matcher + reveal** — `pact-matcher` edge fn (evaluate→decrypt→match), Realtime reveal UI.
  *Accept:* mutual seals → match + reveal; one-sided → nothing; counterparty row unselectable.
  *Complexity:* H. *Deps:* M1. *Risk:* High (correctness + RLS).
- **M3 Growth loop** — invites for non-users, deep-link claim (`app_links`), share (`share_plus`).
  *Accept:* seal a non-user → invite → claim → seal-back → match. *Complexity:* M. *Deps:* M2. *Risk:* Med.
- **M4 Someday List** — non-expiring seals + resurfacing sweep + "past seal matched" alert.
  *Accept:* old seal + later counter-seal → resurfacing match. *Complexity:* M. *Deps:* M2. *Risk:* Med.
- **M5 Safety** — block/report, age-gate, rate limits, moderation queue. *Complexity:* M. *Deps:* M2.
  *Risk:* High (consumer social + minors).
- **M6 Monetization** — Stripe/RevenueCat, Pro tier gates (reveal always free). *Complexity:* M.
  *Deps:* M2. *Risk:* Med (never paywall consent).
- **M7 Professional vertical (Silent Signals)** — pro intent kinds, recruiter/team seats, AI intro.
  *Complexity:* M. *Deps:* M2,M6. *Risk:* Med.
- **M8 AI layer** — icebreakers, who-to-seal, connector agent (flagged). *Complexity:* M. *Deps:* M2.
  *Risk:* Low (additive).
- **M9 Mobile + push** — Android/iOS from one codebase, FCM/APNs. *Complexity:* M. *Deps:* M2.
  *Risk:* Med.
- **M10 Trustless hardening** — on-device encryption (TFHE WASM/FFI) + threshold/2-party key.
  Unlocks "provably unsnoopable" claim. *Complexity:* High. *Deps:* M1. *Risk:* High (crypto).

## Changelog

- **2026-07-06 · Sealed Teaser & Zero-Knowledge Burn Notes.**
  - **Sealed Coming Soon Teaser:** Replaced non-functional AI/Compare widgets in `workspace_tab.dart` with a glowing, animated "Sealed v1.0" preview card. Clicking it launches a multi-step interactive validation bottom sheet (Explainer, Ruleset selection, matching simulation, and interest rating/feedback form) which tags the card as `VALIDATED` on completion.
  - **Zero-Knowledge Burn Notes:** Built a fully functional secret-sharing feature (PrivateBin clone). Encrypts secrets client-side (AES-256) with keys stored only in the URL hash fragment (`/#/burn/<id>#<keyHex>.<ivHex>`). Created an atomic database RPC `read_and_burn_note` that deletes rows instantly on query. Created a secure viewer screen with a 60-second self-destruct countdown, burning animation, and tab-blur tab-switch zeroing. Wired app deep links to bypass standard auth and route directly to the viewer.
- **2026-07-06 · Deep clean: branch reconciliation, disk purge, database full nuke.**
  *Branch reconciliation:* discovered the repo had been switched back to `main` (old pre-pivot
  code) while all Sealed/SecureSend work lived on `pivot/sealed-foundation` — this is why device
  builds had shown the outdated app. `main` was fast-forwarded to the branch tip (`2514db7`),
  the branch pointer deleted, and stray working-tree edits preserved in git stash
  `stray-main-mods-pre-deepclean`. The web-OAuth blank-page fix (redirect `/?code=...` route now
  renders the real app entry instead of an empty widget) was re-applied and committed (`7a6a2a0`).
  *Disk:* removed `services/fhe-compute/target` (39 GB), `build/` (2.7 GB), `releases/` (101 MB),
  `supabase/.branches` — all ignored build artifacts; ~42 GB freed. FHE/Sealed SOURCE stays in the
  repo (founder chose keep-code).
  *Database (founder-approved FULL NUKE):* migration `20260706000000_drop_experiment_subsystems.sql`
  dropped the 12 unused tables (fhe_nonces, fhe_key_metadata, fhe_compute_jobs, fhe_events,
  sealed_profiles, arenas, arena_members, seals, matches, invites, storage_objects, devices) and
  their 4 helper functions; then all app data was wiped — TRUNCATE across every remaining table
  plus `DELETE FROM auth.users` (all accounts removed; everyone re-registers). Live DB is now
  exactly the 9-table product schema, all rows 0, RLS on everywhere.
  *Known leftover:* 11 physical objects in the `secure-files` storage bucket. Direct SQL deletion
  is blocked by Supabase's `storage.protect_delete`, and deploying an unauthenticated purge
  function was (rightly) blocked by policy — empty the bucket via Supabase Dashboard → Storage →
  secure-files → select all → Delete, or `supabase storage rm` with the CLI. Their metadata rows
  are already gone, so the objects are inert orphans until removed.
  *Note:* the sealed/fhe migration FILES stay in the repo (code kept), so a fresh environment
  replaying migrations creates-then-drops those tables, converging on the same schema.
- **2026-07-05 · Product decision: NO SUS = SecureSend; Sealed shelved.** Founder clarified the
  intended product was always "send a document link; recipient views it securely, with or
  without the app" — built the full SecureSend feature this session (see its dedicated section
  above): migration `20260705020000_securesend_share_links.sql`, edge function `share-fetch`
  (deployed, live-smoke-tested), Flutter feature `lib/features/share/*`, `file_card.dart` "Share
  Link" wiring, `AnonymousShareViewerScreen` + `main.dart` boot fork. Verified: `flutter analyze`
  clean; live rollback-protected RLS test proves a non-owner cannot create or read another user's
  share link. **Not verified interactively in-browser** — the sandboxed preview harness in this
  session could not render any Flutter web build (debug or release); root-caused to the
  CanvasKit/WASM engine bootstrap never completing in that specific sandbox (network fetches all
  succeeded, WebGL available, but Dart's `main()` never executed even with diagnostic `print()`
  at its first line) — not a defect in the SecureSend code. A human should open the already-built
  `build/web` in a real browser to confirm visually (see the "Known limitation" note above for
  exact commands). Sealed (M0–M2) is fully built, tested, and live-verified but is now shelved —
  preserved in its own section below rather than deleted, in case of a future pivot back.
- **2026-07-05 · M1+M2 continuation (seal flow + matcher, gap closure).**
  M1 (seal flow) and the M2 `pact-matcher` edge function were built to an
  explicit spec (see `ORIGINAL_REQUEST.md`) with their own passing Dart
  (`test/features/sealed/sealed_repository_test.dart`) and Deno
  (`supabase/functions/pact-matcher/test.ts`) test suites. Rust gained
  `/pact/seal` and `/pact/decrypt` endpoints (`pact_seal_handler`,
  `pact_decrypt_handler`, `compute::decrypt_mutual_match`) so the arena-key
  encrypt/decrypt steps the matcher needs actually exist — verified by
  `cargo test --test pact_test` (4/4, including a new decrypt round-trip).
  **Gap found and closed:** nothing was actually invoking `pact-matcher` — it's
  designed for a Supabase Database Webhook on `seals` INSERT, but no such
  webhook exists (checked: no trigger, no config), so sealing wrote a row, the
  poll loop found nothing, and matches never fired. Rather than embed a
  webhook trigger via SQL migration (real risk of committing the service-role
  key into versioned SQL), `SealedApiClient.runMatcher()` was added so the
  client triggers `pact-matcher` directly right after sealing (best-effort,
  wrapped so a failure can't break `sealChoice`; the existing poll loop stays
  authoritative). This required broadening `pact-matcher`'s auth to accept a
  real user JWT in addition to the service-role key — **but only when
  `sealer_id` in the payload equals the caller's own `auth.uid()`**, so this
  path can never be used to probe or reveal another user's match.
  **Two more bugs fixed:** `fhe-proxy`'s new service-role branch fell back to
  the literal string `"service_role"` as `userId`, which isn't a valid UUID
  and would break the audit-ledger insert on the (rare) replay-detected path
  — changed to `string | null` throughout (`deno check` now clean on all three
  functions: `fhe-proxy`, `pact-matcher`, `sealed-api`). And `seals` RLS didn't
  require arena membership on INSERT (a non-member could write dead,
  permanently-unmatchable rows) — migration `20260705010000_
  sealed_seals_membership_check.sql` tightens `seals_insert_own` to also
  require `is_arena_member(arena_id)`; applied live and verified via
  `pg_policy`.
  **Verified:** `flutter analyze` clean (project-wide); `flutter test` passing
  (both sealed tests, including the mocked seal→matcher→poll flow — note
  postgrest's builders implement `Future<T>` directly, so faking a resolved
  value means stubbing `.then()` on the returned mock, not the chain method
  itself — see `_resolveFilter`/`_resolveTransform` in the test file);
  `deno test` passing for `pact-matcher`.
  **Recommended next manual step (not done here — needs dashboard access):**
  configure a real Supabase Database Webhook on `seals` INSERT → `pact-matcher`
  for instant, no-client-round-trip matching. The client-invoke path already
  makes matching work today without it; once configured, both triggers coexist
  safely (match insert is idempotent via the unique constraint).
- **2026-07-05 · M0 (foundation)** — Added migration `20260705000000_sealed_core.sql`
  (sealed_profiles, arenas, arena_members, seals, matches, invites + RLS + `is_arena_member`/
  `join_arena` RPCs + realtime on matches/seals). Added `FheConfig.enableSealed` flag (in
  `anyEnabled`). Scaffolded `lib/features/sealed/` (5 entities, repository interface,
  `SupabaseSealedRepository`, Riverpod providers, `SealedHomeScreen`). `flutter analyze` clean.
- **2026-07-05 · M0 verified on live DB** — Discovered repo↔DB drift: the live project
  (`rxfnazmusofikwaggntb`) had NONE of the repo's four recent migrations. Applied (user-approved,
  additive-only): `fhe_replay_protection`, `fhe_subsystem`, `storage_router`, `sealed_core`.
  Fixed an ordering bug found during apply (`is_arena_member` must be defined before the
  `arena_members` policy that references it — Postgres validates policies at creation). Ran a
  rollback-protected RLS test on live Postgres: **a user cannot read a counterparty's seal**;
  participants see matches; members see rosters; prod data untouched (0 test rows persisted).
  NOTE for fresh environments: `baseline.sql` is for new DBs only — the live project reached
  baseline state via its own earlier migration chain; do not re-apply it there.
  *Pending:* arena-key encryption correctness (M2).
- **2026-07-05 · Phase A** — Pivot to Sealed decided (strategy in `~/.claude/plans/`). Rescue
  checkpoint `dff6062` on branch `pivot/sealed-foundation`: hardened `.gitignore` (`**/target/`,
  `releases/`, `.agents/`, `.cursor/`, `supabase/.branches/`); committed previously-untracked FHE
  subsystem. Doc checkpoint `9c01d91`: created this file; superseded `AI_HANDOVER.md`.
