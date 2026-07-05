// Verifies the real (non-mock) compute path wired into the /encrypt, /compute
// and /decrypt handlers: per-tenant TFHE keys from TENANT_KEY_STORE, real
// encryption, a homomorphic sum evaluated under the tenant's server key, and
// decryption back to plaintext.

use base64::Engine as _;
use fhe_compute::compute;
use fhe_compute::crypto::{FheCryptosystem, TFHEEngine, TENANT_KEY_STORE};

fn encrypt_b64(engine: &TFHEEngine, key: &tfhe::ClientKey, value: u32) -> String {
    let ct = engine.encrypt(value, key).expect("encrypt");
    let bytes = engine.serialize_uint32(&ct).expect("serialize");
    base64::prelude::BASE64_STANDARD.encode(bytes)
}

#[test]
fn test_real_tenant_compute_roundtrip_sum() {
    let engine = TFHEEngine;
    let tenant = "test-tenant-roundtrip";
    let keys = TENANT_KEY_STORE.get_or_create(tenant);

    let a = 45u32;
    let b = 15u32;
    let ct_a = encrypt_b64(&engine, &keys.client_key, a);
    let ct_b = encrypt_b64(&engine, &keys.client_key, b);

    // Same steps as compute_handler: load the tenant's server key, then evaluate.
    tfhe::set_server_key(keys.server_key.clone());
    let result_b64 = compute::homomorphic_sum(&[ct_a, ct_b]);

    // Same steps as decrypt_handler.
    let result_bytes = base64::prelude::BASE64_STANDARD
        .decode(&result_b64)
        .expect("decode result");
    let result_ct = engine.deserialize_uint32(&result_bytes).expect("deserialize");
    let decrypted = engine.decrypt(&result_ct, &keys.client_key).expect("decrypt");

    assert_eq!(
        decrypted,
        a + b,
        "homomorphic sum over tenant keys must equal the plaintext sum"
    );
}

#[test]
fn test_tenant_key_store_is_stable_per_tenant() {
    // Repeated lookups for the same tenant must return the SAME key material,
    // otherwise ciphertexts from an /encrypt call would not decrypt on a later
    // /decrypt call within the same session.
    let tenant = "test-tenant-stable";
    let k1 = TENANT_KEY_STORE.get_or_create(tenant);
    let k2 = TENANT_KEY_STORE.get_or_create(tenant);
    assert!(
        std::sync::Arc::ptr_eq(&k1, &k2),
        "same tenant must reuse cached keys"
    );
    assert!(TENANT_KEY_STORE.contains(tenant));
}

#[test]
fn test_distinct_tenants_get_isolated_keys() {
    let a = TENANT_KEY_STORE.get_or_create("tenant-a");
    let b = TENANT_KEY_STORE.get_or_create("tenant-b");
    assert!(
        !std::sync::Arc::ptr_eq(&a, &b),
        "different tenants must not share key material"
    );
}

/// Key metadata lifecycle (item #3): fingerprint format, rotation changing the
/// fingerprint, and revocation dropping the tenant's cached keys.
#[test]
fn test_key_lifecycle_fingerprint_rotate_revoke() {
    let tenant = "test-tenant-lifecycle";

    // Fresh generation yields a 64-hex-char SHA-256 fingerprint.
    let k1 = TENANT_KEY_STORE.get_or_create(tenant);
    assert_eq!(k1.fingerprint.len(), 64, "fingerprint must be a SHA-256 hex digest");
    assert!(k1.fingerprint.chars().all(|c| c.is_ascii_hexdigit()));

    // Rotation produces fresh key material => a different fingerprint.
    let k2 = TENANT_KEY_STORE.regenerate(tenant);
    assert_ne!(k1.fingerprint, k2.fingerprint, "rotation must change the fingerprint");

    // Revocation drops the keys; the tenant is no longer cached.
    assert!(TENANT_KEY_STORE.revoke(tenant));
    assert!(!TENANT_KEY_STORE.contains(tenant));
    // Revoking again is a no-op reporting nothing was present.
    assert!(!TENANT_KEY_STORE.revoke(tenant));

    // A subsequent access regenerates fresh material (new fingerprint again).
    let k3 = TENANT_KEY_STORE.get_or_create(tenant);
    assert_ne!(k2.fingerprint, k3.fingerprint, "post-revocation keys must be fresh");
}

/// Async-worker path (item #2): a job submitted to the in-process queue with a
/// tenant_id must be picked up by a background worker, evaluated under that
/// tenant's ServerKey, and produce a result that decrypts correctly.
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn test_async_worker_evaluates_tenant_job() {
    use fhe_compute::models::ComputeRequest;
    use fhe_compute::services::aggregation::DISTRIBUTED_QUEUE;

    let engine = TFHEEngine;
    let tenant = "test-tenant-async";
    let keys = TENANT_KEY_STORE.get_or_create(tenant);

    let a = 7u32;
    let b = 5u32;
    let ct_a = encrypt_b64(&engine, &keys.client_key, a);
    let ct_b = encrypt_b64(&engine, &keys.client_key, b);

    let job_id = DISTRIBUTED_QUEUE
        .submit_job(ComputeRequest {
            key_id: "async-demo-key".to_string(),
            operation: "SUM".to_string(),
            ciphertexts: vec![ct_a, ct_b],
            priority: Some(1),
            timeout_seconds: Some(300), // homomorphic add is slow in debug builds
            tenant_id: Some(tenant.to_string()),
            job_id: None, // no Supabase mirror in tests
        })
        .expect("job submission");

    // Poll until the background worker completes the evaluation.
    let mut result_b64: Option<String> = None;
    for _ in 0..300 {
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        let status = DISTRIBUTED_QUEUE
            .get_job_status(&job_id)
            .expect("job must be tracked");
        match status.status.as_str() {
            "completed" => {
                result_b64 = status.result;
                break;
            }
            "failed" | "dead_letter" | "cancelled" => {
                panic!("async job ended in state {}", status.status);
            }
            _ => continue,
        }
    }
    let result_b64 = result_b64.expect("worker did not complete the job in time");

    let result_bytes = base64::prelude::BASE64_STANDARD
        .decode(&result_b64)
        .expect("decode result");
    let result_ct = engine.deserialize_uint32(&result_bytes).expect("deserialize");
    let decrypted = engine.decrypt(&result_ct, &keys.client_key).expect("decrypt");
    assert_eq!(decrypted, a + b, "async homomorphic sum must equal plaintext sum");
}
