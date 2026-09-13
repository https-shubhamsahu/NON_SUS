# NO SUS

Share a sensitive document. Still see who opened it.

NO SUS is a Flutter + Supabase product for controlled document sharing: tracked links, one-time drops, and a recipient flow that does not require an account.

![Flutter](https://img.shields.io/badge/Flutter-3.44-02569B?style=flat-square&logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Postgres_%2B_Edge_Functions-3ECF8E?style=flat-square&logo=supabase&logoColor=white)
![Riverpod](https://img.shields.io/badge/State-Riverpod_3-blue?style=flat-square)

## What it does

- **Tracked shares** — send a document, watermark the view, and see when it was opened
- **Burn notes / files** — one-time encrypted drops; the key lives in the link fragment
- **Pairing codes** — send the link, then tell them a 2-digit code. The unguessable token in `/#/r/<token>` is the real secret
- **Groups & vault** — keep files with people you already work with

The core product does not use AI, FHE, or blockchain. Optional intelligence adapters can be compiled in for competitions.

## Architecture

| Path | What it is |
|---|---|
| `lib/` | Flutter app (Android + web) |
| `supabase/` | Postgres migrations + Edge Functions |
| `homepage/` | Next.js marketing site at `nosus.foo` |
| `lib/features/intelligence/` | Optional AI adapters (`disabled` / `gemini` / `local`) |

The Flutter web app deploys to `app.nosus.foo`. Burn links already in the wild must keep parsing — see `test/unit/deep_link_parsing_test.dart`.

**Intentionally removed:** FHE / Sealed (TFHE-rs, `fhe-proxy`, `sealed-api`). Historical SQL migrations stay; they are not the active product.

## Setup

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

## License

MIT — see [`LICENSE`](./LICENSE).
