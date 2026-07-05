# FHE — Continuation Handoff (for Claude Code)

Pick up the FHE subsystem here. Full context is in `INTEGRATION_GUIDE.md`
(what changed) and `FREE_STORAGE_STRATEGY.md` (storage plan). Read those first.

## Ground rules (unchanged)
- Additive only. Do NOT modify existing AES storage, upload, download, sharing,
  document viewing, auth, or existing Supabase objects.
- Everything stays behind granular flags in `lib/config/fhe_config.dart`,
  default OFF.
- Never log or persist plaintext, ciphertext, key material, or key fingerprints.

## First thing to do: verify the wiring compiles
```bash
# Rust
cd services/fhe-compute && cargo build && cargo test

# Flutter (from repo root)
flutter pub get && flutter analyze
```
Fix any residual issues first (most likely unused-import lints from the rewire).

## Remaining work, in priority order
1. **Real compute path in Rust.** ✅ DONE. `/encrypt` `/decrypt` `/compute` and
   `/keys/generate` now use the real `TFHEEngine` (not `MockEngine`), backed by a
   per-tenant live-key store (`src/crypto/tenant_keys.rs`, `TENANT_KEY_STORE`)
   keyed on the `X-Tenant-Id` header the `fhe-proxy` sends (local-dev falls back
   to a shared `local-dev-tenant`). `/compute` loads the tenant's `ServerKey`
   via `set_server_key` before evaluating. Verified by
   `tests/real_compute_path_test.rs` (encrypt 45 + 15 → homomorphic sum →
   decrypt → 60, plus per-tenant isolation). Keys are RAM-only, never persisted
   or logged. NOTE: interim design holds each tenant's `ClientKey` server-side;
   long-term, move encrypt/decrypt on-device (TFHE WASM/FFI) so the server only
   evaluates. `compare`/`mux`/`similarity`/`memory_search`/`policy_evaluate` are
   also tenant-wired (each sets the tenant `ServerKey` before evaluating),
   though only encrypt/compute/decrypt have roundtrip test coverage so far.
2. **Async worker.** ✅ MOSTLY DONE. `ComputeRequest` now carries `tenant_id` +
   `job_id` (serde-defaulted, additive); `/jobs` stamps the tenant from
   `X-Tenant-Id` (header is authoritative, body value overridden); the queue
   worker (`execute_job`) loads the tenant's `ServerKey` via `TENANT_KEY_STORE`
   before evaluating; and on completion / permanent failure the worker mirrors
   `status`/`progress`/`result_ciphertext`/`error` back to the Supabase
   `fhe_compute_jobs` row via PostgREST (`src/services/job_sync.rs`, service-role
   key; silent no-op when SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are unset).
   Internal `processing` maps to DB `running` (check-constraint vocabulary).
   Verified by `test_async_worker_evaluates_tenant_job` in
   `tests/real_compute_path_test.rs`. REMAINING: the job_sync writeback is
   untested against a live Supabase (needs the two env secrets on the Rust
   host), and intermediate progress updates (`running`, retries) are not yet
   mirrored — only terminal states are.
3. **Key metadata lifecycle.** ✅ MOSTLY DONE. `TenantKeys` now carries a
   non-secret `fingerprint` (SHA-256 hex of the serialized evaluation/ServerKey);
   `/keys/generate` returns it as `public_fingerprint`, and new `/keys/rotate`
   (regenerate) + `/keys/revoke` (drop) endpoints exist over `TENANT_KEY_STORE`.
   The `fhe-proxy` transitions the `fhe_key_metadata` row on each action
   (upsert active on generate; retire active→rotated + insert new active on
   rotate; active→revoked on revoke — keyed by fingerprint, RLS-bypassing
   service-role writes) and logs the matching `fhe_key_generated`/`_rotated`/
   `_revoked` event (event metadata stays fingerprint-free per the ledger rule).
   Flutter `FheEngine.rotateKeys()`/`revokeKeys()` + transport actions added.
   Verified in Rust by `test_key_lifecycle_fingerprint_rotate_revoke`.
   REMAINING: (a) **expiry** — `expires_at` column + `expired` status exist but
   nothing sets/enforces them yet (add a TTL on generate + a sweep, or a DB cron
   that flips active→expired past `expires_at`); (b) the proxy metadata writes
   are untested against a live Supabase; (c) no FHE Lab UI triggers rotate/revoke
   yet (methods are callable programmatically).
4. **storage-router Edge Function** per `FREE_STORAGE_STRATEGY.md` to make the
   multi-cloud free-storage plan runnable (optional, flag-gated).
5. **End-to-end device test.** Flag on → Profile → Labs → FHE Lab → homomorphic
   add → confirm rows land in `fhe_events`.

## Files touched last session
- `lib/config/fhe_config.dart` (granular flags)
- `lib/features/fhe/data/fhe_transport.dart` (new, single transport)
- `lib/features/fhe/domain/fhe_engine.dart`, `.../fhe_key_manager.dart`
- `lib/features/fhe/data/repositories/fhe_repository_impl.dart`
- `lib/features/fhe/presentation/providers/fhe_provider.dart`
- `lib/features/profile/presentation/screens/profile_screen.dart` (Labs entry)
- `supabase/migrations/20260704000000_fhe_subsystem.sql`
- `supabase/functions/fhe-proxy/index.ts`
- `services/fhe-compute/src/api/mod.rs`, `.../crypto/engine.rs`
