# NO SUS — SHIELD SUBSYSTEM (SHELVED)
> Reference guide for the Fully Homomorphic Encryption (FHE) subsystem of NO SUS. 
> Keep this document intact to preserve system designs for future un-shelving.

---

## 1. Vision & Purpose
The Shield subsystem provides privacy-preserving computation over encrypted data. While standard storage utilizes AES for encryption-at-rest, computation (such as comparing private intents or research matching) is computed over ciphertext using homomorphic encryption primitives. 

* **AES protects storage.**
* **FHE protects computation.**

---

## 2. Overall Architecture
```text
Flutter Client
   │ (FheTransport sends encrypted inputs + CompactPublicKey)
   ▼
Supabase Edge Function (fhe-proxy)
   │ (Validates JWT, tenant isolation, replay guard, logs audit event)
   ▼
Rust FHE Microservice (TFHE-rs)
   │ (Performs homomorphic gates: addition, multiplication, MUX, comparison)
   ▼
Return Encrypted Result to client
```

* **Client Isolation**: The Flutter app never interacts directly with TFHE-rs internals or keys.
* **Server Trust Boundaries**: The Supabase database stores only metadata and fingerprints. Private keys are never persisted.

---

## 3. Rust Compute Service (`services/fhe-compute`)
A containerized Rust microservice built on Zama's **TFHE-rs** engine. 

### Core Structure:
* `src/crypto`: Core TFHE parameters, encryption/decryption models.
* `src/compute`: Homomorphic circuit definitions.
  * `pact.rs`: Contains `homomorphic_mutual_match`—the mutual intent matching engine (takes encrypted `FheBool` inputs of choice indices and returns a mutual-match boolean ciphertext).
* `src/api`: REST routes behind service bearer auth (`FHE_SERVICE_TOKEN`).
  * `/keys/*`: Lifecycle operations (generate, rotate, revoke).
  * `/pact/evaluate`: Computes mutual intent matches for Sealed.
  * `/pact/seal`: Encrypts/evaluates base choices.
  * `/pact/decrypt`: Recovers results over decrypted mutual match ciphertexts.

---

## 4. Edge Functions
1. **`fhe-proxy`**: The gatekeeper. Handles replay protection (nonce caching), timestamp validations, and passes tenant-specific header (`X-Tenant-Id`) to target container hosts.
2. **`pact-matcher`**: Intercepts `seals` updates or direct API triggers, invokes the Rust microservice for FHE evaluation, and writes back findings to the database.
3. **`sealed-api`**: Exposes Sealed-related endpoints to clients.

---

## 5. Security & Isolation Designs
* **Replay Protection**: Prevents ciphertext replay attacks using `fhe_nonces` and 5-minute time windows.
* **Multi-Tenant Separation**: Worker execution environments are strictly isolated per user/tenant context.
* **Key Lifecycle Management**: Tracks active, rotated, revoked, and expired public keys without storing client-side private keys.
* **Memory Protection**: Utilizes Linux `mlock` and virtual memory zeroization on worker shutdowns to wipe sensitive key states.

---

## 6. Reactivation Checklist
To un-shelve and activate the Sealed / FHE modules:
1. Re-apply the FHE and Sealed migrations in chronological order:
   * `20260704000000_fhe_subsystem.sql`
   * `20260705000000_sealed_core.sql`
   * `20260705010000_sealed_seals_membership_check.sql`
2. Start the Rust container in `services/fhe-compute/` on a secure host and set:
   * `FHE_COMPUTE_URL`
   * `FHE_SERVICE_TOKEN`
3. Deploy the Edge Functions: `fhe-proxy`, `pact-matcher`, `sealed-api`.
4. In Flutter, toggle the feature flag in `lib/config/fhe_config.dart` or pass `--dart-define=enableSealed=true` at compile time.
5. Create a Postgres Database Webhook trigger pointing to the `pact-matcher` Edge Function on `seals` inserts for real-time automatic matching.
