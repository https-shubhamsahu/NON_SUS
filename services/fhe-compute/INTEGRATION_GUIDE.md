# NO SUS — FHE Integration & Build Guide

This session wired the existing FHE scaffold into the app end-to-end. Everything
is **off by default** and **additive** — no existing AES storage, upload,
download, sharing, viewing, or auth flow was modified.

## What changed this session

**Flutter (`lib/`)**
- `config/fhe_config.dart` — replaced the single global switch with **granular
  flags** (all default `false`): `enableKeyGeneration`, `enablePrivateMemory`,
  `enablePolicyEngine`, `enableHomomorphicSearch`, `enableBenchmarks`,
  `enableSelectiveTruth`, plus endpoint config.
- `features/fhe/data/fhe_transport.dart` — **new** single transport. All FHE
  traffic goes through `Supabase.functions.invoke('fhe-proxy')` (auto-attaches
  the user JWT). Local-dev direct mode is behind `FHE_USE_LOCAL_COMPUTE`.
- `features/fhe/domain/fhe_engine.dart`, `data/repositories/fhe_repository_impl.dart`,
  `presentation/providers/fhe_provider.dart` — rewired off the hardcoded
  `http://10.0.2.2:8080` + static token and onto the transport / RLS tables.
- `features/profile/.../profile_screen.dart` — added a **flag-gated "FHE Lab"**
  entry that only renders when `FheConfig.anyEnabled` is true.

**Supabase**
- `migrations/20260704000000_fhe_subsystem.sql` — `fhe_key_metadata`,
  `fhe_compute_jobs`, `fhe_events` with RLS + tenant isolation + realtime on
  jobs. **No secret key material is stored.**
- `functions/fhe-proxy/index.ts` — **new** Edge Function: authenticates JWT,
  enforces replay (nonce + timestamp via existing `fhe_nonces`), forwards to the
  Rust service, mirrors jobs, writes the audit ledger.

**Rust (`services/fhe-compute/`)**
- `api/mod.rs` — added `/memory/search` and `/policy/evaluate` routes.
- `crypto/engine.rs` — replaced the static parameter stub with a real SHA-256
  parameter fingerprint + version constants.

## ⚠️ Not verified in this environment
Neither `cargo` nor `flutter` exists in the build sandbox used this session, so
the code was written but **not compiled here**. Run the commands below on your
machine to compile, test, and fix any residual issues.

---

## Build & run

### 1. Rust microservice
```bash
cd services/fhe-compute
cargo build --release        # first build pulls tfhe-rs; takes a while
cargo test                   # module + integration tests
cargo bench                  # criterion benchmarks (optional)
FHE_SERVICE_TOKEN=dev-token ./target/release/fhe-compute   # runs on :8080
```
Or Docker: `docker compose up --build` (see `docker-compose.yml`, non-root +
read-only fs + seccomp already configured).

### 2. Supabase (migration + function)
```bash
supabase db push                                   # applies the FHE migration
supabase functions deploy fhe-proxy
supabase secrets set FHE_COMPUTE_URL=https://<your-rust-host> \
                     FHE_SERVICE_TOKEN=<same token the Rust service trusts>
```

### 3. Flutter app — enable a capability (off by default)
```bash
# Production path (through Supabase Edge Function):
flutter run --dart-define-from-file=.env \
  --dart-define=FHE_ENABLE_BENCHMARKS=true

# On-device dev against a local Rust service (bypasses Supabase):
flutter run --dart-define-from-file=.env \
  --dart-define=FHE_ENABLE_BENCHMARKS=true \
  --dart-define=FHE_USE_LOCAL_COMPUTE=true
```
With a flag on, the **FHE Lab** appears in Profile → Labs (Experimental). With
all flags off (default), the app behaves exactly as before.

---

## End-to-end flow (once enabled)
```
Flutter (flag on) → FheTransport → Supabase fhe-proxy (JWT + replay check)
   → Rust fhe-compute (TFHE-rs) → result → mirror to fhe_compute_jobs
   → realtime push → Flutter
```

## Recommended remaining work (next sessions)
1. **Rust handlers still use `MockEngine`/dev fallbacks** for encrypt/decrypt and
   a stub `homomorphic_sum`. Wire `/compute`, `/encrypt`, `/decrypt` to the real
   `TFHEEngine` + a key store keyed by `X-Tenant-Id`. (Architecturally,
   encryption/decryption should move on-device via TFHE WASM/FFI; the server
   should only evaluate.)
2. **Async worker**: a background worker that drains `fhe_compute_jobs`, runs the
   evaluation, and writes `result_ciphertext` + status (the proxy currently
   forwards synchronously and mirrors the row).
3. **Key metadata writes**: have `generate_keys` insert into `fhe_key_metadata`
   (fingerprint only) and support rotation/revocation/expiry transitions.
4. **Test the full path** on a device: flag on → Lab → homomorphic add → verify
   the audit rows in `fhe_events`.

See `FREE_STORAGE_STRATEGY.md` for the zero-cost multi-cloud storage plan.
