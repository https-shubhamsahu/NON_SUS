---
paths:
  - "lib/features/fhe/**"
  - "lib/config/fhe_config.dart"
  - "services/fhe-compute/**"
  - "supabase/functions/fhe-proxy/**"
---

(From `.cursor/rules/no-sus-fhe.mdc`; applies to `lib/features/fhe/`, `lib/config/fhe_config.dart`, `services/fhe-compute/`, `supabase/functions/fhe-proxy/`. Full context in `services/fhe-compute/NEXT_SESSION.md` and `INTEGRATION_GUIDE.md`. `SHIELD.md` documents the (shelved) architecture that reuses this same FHE spine: `lib/features/sealed/`, `supabase/functions/{sealed-api,pact-matcher}` — kept in the repo but not the active product, per `PROJECT_CONSTITUTION.md` §4.)

- **Additive only.** Never modify existing AES storage, upload/download, sharing, viewing, auth, or existing Supabase objects. FHE is for encrypted *computation*; AES stays responsible for storage.
- **Off by default.** Every capability sits behind a granular flag in `lib/config/fhe_config.dart`; never add a single global FHE switch.
- **Flutter never talks to TFHE directly.** Traffic path: app → `FheTransport` → `fhe-proxy` Edge Function → Rust `fhe-compute`.
- **Never log or persist** plaintext, ciphertext, key material, or key fingerprints. Supabase stores metadata only; private keys never leave RAM/device.
- Keep the crypto backend behind the `FheCryptosystem` trait so other engines can be swapped in.
- Before claiming FHE work done: `cargo build && cargo test` in `services/fhe-compute` AND `flutter analyze` at repo root, both clean.
