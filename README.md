# NO SUS

A document-sharing product for the moment after you hit send: share a sensitive file, see when it opens, and keep simple control over access without asking recipients to create an account.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres_%2B_Edge_Functions-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Riverpod](https://img.shields.io/badge/State-Riverpod_3-blue?style=flat-square)

## What it does

- **Tracked shares** — send a document, watermark the view, and see when it was opened
- **Burn notes / files** — one-time encrypted drops; the key lives in the link fragment
- **Pairing codes** — send the link, then tell them a 2-digit code. The unguessable token in `/#/r/<token>` is the real secret
- **Groups & vault** — keep files with people you already work with

The full authoritative product and engineering philosophy lives in [`PROJECT_CONSTITUTION.md`](./PROJECT_CONSTITUTION.md); this README is the practical entry point.

## Shipped Features (V1)

- **SecureSend** — share links with expiration dates, view-count limits, touch-to-reveal blur, dynamic recipient-email watermarks, and real-time view logs
- **Burn Notes / Burn Files** — client-side AES-256 encrypted short notes and files; encryption keys travel only in the URL hash fragment and are never sent to the server; content is destroyed atomically on read
- **Study group workspace** — file sharing, groups, audit logging, and a risk/abuse-detection engine (multi-device detection, suspicious view-event tracking)
- **Redemption pairing & invites** — group invites plus a quick two-digit confirmation flow. The two digits always travel with an unguessable pairing link; they are not an access credential by themselves.

> Marketing and in-app copy is deliberately scoped to what's cryptographically true today — e.g. no screenshot-proofing claims (not possible in-browser) ahead of what's actually implemented.

## Architecture

| Path | What it is |
|---|---|
| `lib/`, `test/`, `android/`, `web/` | The Flutter app (web + Android), the root of this repo |
| `supabase/` | Postgres migrations + Deno Edge Functions (`burn-file-*`, `share-fetch`, `share-heartbeat`, `redeem-code`, …) |
| `homepage/` | Next.js marketing landing page, statically exported, served at the `nosus.foo` root |

The Flutter web app deploys to `app.nosus.foo`. Burn links already in the wild must keep parsing — see `test/unit/deep_link_parsing_test.dart`.

**Security model:**
- Every table has Row-Level Security enabled — RLS must hold even if a client is fully compromised.
- The client never talks directly to server-only services or external storage; sensitive operations go through scoped Supabase Edge Functions.
- Burn Notes/Files are encrypted client-side and the key travels in the link's URL fragment. To support short 2-digit codes, single-target shares also store the key server-side in `burn_redemption_codes` until the code is used or expires (20 minutes by default); multi-file shares never send it.

**State management:** Riverpod 3. Feature-first layout under `lib/features/<feature>/` (`data/`, `domain/`, `presentation/`); cross-cutting singletons (audit, screenshot guard, device integrity, risk engine) live in `lib/services/`.

## Tech Stack

| Layer | Technology |
|---|---|
| Client | Flutter 3.44 (web + Android), Riverpod 3, Rive (mascot animations) |
| Backend | Supabase (Postgres, Auth, Storage, RLS, Edge Functions on Deno) |
| Marketing site | Next.js (static export) |
| Crypto | AES-256 client-side (`encrypt` package) for burn notes/files |

## Getting Started

### Prerequisites
- Flutter SDK (stable, matching `.metadata`)
- A Supabase project (or leave `lib/config/supabase_credentials.dart` empty to run in local mock-fallback mode with no backend)

### Setup

```bash
flutter pub get
cp .env.example .env   # Supabase URL + anon key, or leave empty for mock mode
flutter analyze
flutter test
flutter build web --base-href "/"
```

Optional intelligence:

```bash
flutter run --dart-define=INTELLIGENCE_PROVIDER=local
flutter run --dart-define=INTELLIGENCE_PROVIDER=gemini   # needs Edge Function + GEMINI_API_KEY
```

### Homepage (marketing site)

```bash
cd homepage
npm install
npm run dev
```

## Project Structure

```
lib/
├── components/secure_viewer/
├── config/                  # Supabase credentials, runtime configuration, storage router config
├── core/                    # Supabase bootstrap, theme, mascot, providers
├── features/
│   ├── auth/  files/  groups/  notes/  workspace/  vault/
│   ├── audit/  admin/  config/  focus/  onboarding/  profile/
│   ├── share/                # SecureSend
├── screens/
└── services/                 # audit, screenshot guard, device integrity, risk engine

supabase/
├── functions/                # Edge Functions (Deno)
└── migrations/                # Incremental, idempotent SQL migrations

homepage/                      # Next.js marketing site (static export)
```

## Optional hackathon capabilities

AI is not part of the normal product path. Any future Gemini or on-device capability must be a feature-flagged adapter behind a product-facing document-assistance interface, with provider keys held only by a server-side integration. The core sharing, viewing, and audit flows must continue to work when every adapter is disabled.

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
