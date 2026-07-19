# NO SUS

A secure, tracked, watermarked document-sharing and private-messaging platform — built so senders keep full visibility and control over external access, without forcing recipients to register or install anything.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres_%2B_Edge_Functions-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-TFHE--rs-DEA584?style=flat-square&logo=rust&logoColor=black)
![Riverpod](https://img.shields.io/badge/State-Riverpod_3-blue?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

## Overview

NO SUS targets three use cases: professionals sharing sensitive documents with external counterparties, privacy-conscious users exchanging one-time secrets over a self-destructing channel, and researchers collaborating on sensitive data without raw exposure. The product is built for a single-developer, zero-budget operating model — leaning on generous free tiers (Supabase, Cloudflare) and avoiding operational overhead wherever possible.

The full authoritative product and engineering philosophy lives in [`PROJECT_CONSTITUTION.md`](./PROJECT_CONSTITUTION.md); this README is the practical entry point.

## Shipped Features (V1)

- **SecureSend** — share links with expiration dates, view-count limits, touch-to-reveal blur, dynamic recipient-email watermarks, and real-time view logs
- **Burn Notes / Burn Files** — client-side AES-256 encrypted short notes and files; encryption keys travel only in the URL hash fragment and are never sent to the server; content is destroyed atomically on read
- **Study group workspace** — file sharing, groups, audit logging, and a risk/abuse-detection engine (multi-device detection, suspicious view-event tracking)
- **Redemption codes & invites** — group invites and one-time redemption codes for controlled access

## In Progress / Shelved

- **FHE subsystem** (`lib/features/fhe/`) — an additive, flag-gated homomorphic-compute path (Rust/TFHE-rs) for encrypted computation, kept fully separate from the AES storage path that backs the shipped features above
- **Sealed** (`lib/features/sealed/`) — a reciprocity-gated intent-matching system built on the same FHE spine; currently shelved (see [`SHIELD.md`](./SHIELD.md)) and not part of the active product

> Marketing and in-app copy is deliberately scoped to what's cryptographically true today — e.g. no screenshot-proofing claims (not possible in-browser) ahead of what's actually implemented.

## Architecture

This is a monorepo with four parts:

| Path | What it is |
|---|---|
| `lib/`, `test/`, `android/`, `web/` | The Flutter app (web + Android), the root of this repo |
| `supabase/` | Postgres migrations + Deno Edge Functions (`burn-file-*`, `share-fetch`, `share-heartbeat`, `fhe-proxy`, `sealed-api`, `redeem-code`, …) |
| `services/fhe-compute/` | Isolated Rust (TFHE-rs) homomorphic-compute service, reached only via the `fhe-proxy` Edge Function |
| `homepage/` | Next.js marketing landing page, statically exported, served at the `nosus.foo` root |

**Deployment split:** the Flutter web app is built and deployed to a separate repo ([`nosus-app`](https://github.com/https-shubhamsahu/nosus-app)) serving `app.nosus.foo`; this repo's own `gh-pages` branch serves the `homepage/` landing site at `nosus.foo`. Legacy deep links (`nosus.foo/#/burn|burnfile|v|join/...`) are forwarded from the landing page to the app subdomain with the fragment (and therefore the encryption key) preserved.

**Security model:**
- Every table has Row-Level Security enabled — RLS must hold even if a client is fully compromised.
- The client never talks directly to internal compute services or external storage; all such calls go through authenticated Supabase Edge Functions.
- For zero-knowledge features (Burn Notes/Files), encryption keys are generated and used entirely client-side and never touch the server database or logs.

**State management:** Riverpod 3. Feature-first layout under `lib/features/<feature>/` (`data/`, `domain/`, `presentation/`); cross-cutting singletons (audit, screenshot guard, device integrity, risk engine) live in `lib/services/`.

## Tech Stack

| Layer | Technology |
|---|---|
| Client | Flutter 3.44 (web + Android), Riverpod 3, Rive (mascot animations) |
| Backend | Supabase (Postgres, Auth, Storage, RLS, Edge Functions on Deno) |
| Homomorphic compute | Rust + TFHE-rs, containerized, reached via Edge Function proxy only |
| Marketing site | Next.js (static export) |
| Crypto | AES-256 client-side (`encrypt` package) for burn notes/files |

## Getting Started

### Prerequisites
- Flutter SDK (stable, matching `.metadata`)
- A Supabase project (or leave `lib/config/supabase_credentials.dart` empty to run in local mock-fallback mode with no backend)

### Setup

```bash
flutter pub get
cp .env.example .env   # fill in Supabase URL/anon key if using a real backend
```

### Run

```bash
flutter analyze                      # must be clean
flutter test                         # full test suite
flutter build web --base-href "/"    # web release build
```

### Homepage (marketing site)

```bash
cd homepage
npm install
npm run dev
```

### FHE compute service (optional, Rust)

```bash
cd services/fhe-compute
cargo build
cargo test
```

## Project Structure

```
lib/
├── components/secure_viewer/
├── config/                  # Supabase credentials, FHE flags, storage router config
├── core/                    # Supabase bootstrap, theme, mascot, providers
├── features/
│   ├── auth/  files/  groups/  notes/  workspace/  vault/
│   ├── audit/  admin/  config/  focus/  onboarding/  profile/
│   ├── share/                # SecureSend
│   └── fhe/  sealed/         # Encrypted-compute subsystem (flag-gated)
├── screens/
└── services/                 # audit, screenshot guard, device integrity, risk engine

supabase/
├── functions/                # Edge Functions (Deno)
└── migrations/                # Incremental, idempotent SQL migrations

services/fhe-compute/          # Rust TFHE-rs homomorphic-compute service
homepage/                      # Next.js marketing site (static export)
```

## CI/CD

- `.github/workflows/gh-pages.yml` — on push to `main`: analyze, build web, deploy (two jobs: `landing` for this repo's `gh-pages`, `app` for the `nosus-app` deploy target)
- `.github/workflows/play-store-release.yml` — on `v*.*.*` tags: builds a signed AAB, publishes a GitHub Release with the APK, uploads to the Play internal track

## Engineering Principles

- Every new table gets Row-Level Security; SQL migrations are incremental and never edited after landing
- No parallel v2/v3 duplicate files — features are edited in place
- Copy and marketing claims are scoped to match actual cryptographic guarantees

See [`PROJECT_CONSTITUTION.md`](./PROJECT_CONSTITUTION.md) for the full product vision and non-negotiable engineering rules.

## License

MIT — see [`LICENSE`](./LICENSE).
