# PROJECT_HANDOVER.md — Single Source of Truth

> **Read this first.** This file supersedes the old `AI_HANDOVER.md` (deleted) and is the
> authoritative handover. `README.md` / `AGENTS.md` are secondary. Any future AI or developer
> should be able to continue development from this file + the repository alone. Keep it in sync
> after **every** coding session (see [Daily Workflow](#daily-workflow)).
>
> **Status (2026-07-05):** mid-pivot. The shipped app is **NO SUS** (secure study-group document
> workspace). We are pivoting to **Sealed** (a reciprocity-gated *intent graph*) on the same
> stack. Both are documented here; the pivot is additive and reuses the existing FHE spine.

---

## Vision

**Sealed lets people privately express an intent toward a specific person — romantic, platonic,
professional, or reconnection — that is revealed only if it is mutual.** A non-mutual signal is
never exposed. The reveal is computed over ciphertext by an existing FHE mutual-match primitive,
so the platform's trust story is cryptographic, not policy-based.

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

- **2026-07-05 · M0 (foundation)** — Added migration `20260705000000_sealed_core.sql`
  (sealed_profiles, arenas, arena_members, seals, matches, invites + RLS + `is_arena_member`/
  `join_arena` RPCs + realtime on matches/seals). Added `FheConfig.enableSealed` flag (in
  `anyEnabled`). Scaffolded `lib/features/sealed/` (5 entities, repository interface,
  `SupabaseSealedRepository`, Riverpod providers, `SealedHomeScreen`). `flutter analyze` clean.
  *Pending:* live migration apply (needs a Supabase env); arena-key encryption correctness (M2).
- **2026-07-05 · Phase A** — Pivot to Sealed decided (strategy in `~/.claude/plans/`). Rescue
  checkpoint `dff6062` on branch `pivot/sealed-foundation`: hardened `.gitignore` (`**/target/`,
  `releases/`, `.agents/`, `.cursor/`, `supabase/.branches/`); committed previously-untracked FHE
  subsystem. Doc checkpoint `9c01d91`: created this file; superseded `AI_HANDOVER.md`.
