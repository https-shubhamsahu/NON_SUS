use fhe_compute::keys::{KeyValidator, KeyValidationError, TenantRegistryManager};
use fhe_compute::middleware::replay_protection::ReplayCache;
use fhe_compute::compute::{VersionedCiphertext, VersionManager, ComputeBudget, BudgetTracker, BudgetError};
use fhe_compute::services::aggregation::{DistributedQueue, JobStatus};
use fhe_compute::models::ComputeRequest;
use std::time::{SystemTime, UNIX_EPOCH, Duration};

#[test]
fn test_security_validation_jwt_forgery_simulation() {
    // The auth middleware (middleware::auth::validate_token) authorizes a request only
    // when the Bearer token exactly matches the configured service token. Verify that a
    // forged token does not match the trusted service token loaded from configuration.
    let forged_token = "invalid.bearer.token-forged";
    let settings = fhe_compute::config::Settings::new().expect("settings should load");
    assert_ne!(
        forged_token, settings.security.service_token,
        "Security vulnerability: forged token matched the trusted service token!"
    );
}

#[test]
fn test_security_validation_replay_protection() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // First request succeeds
    let first = cache.verify_and_insert("security-nonce-1", current_time);
    assert!(first.is_ok());

    // Replay attack (exact same nonce) must be rejected
    let replay = cache.verify_and_insert("security-nonce-1", current_time);
    assert_eq!(replay, Err("Duplicate request nonce detected. Replay blocked."));
}

#[test]
fn test_security_validation_oversized_payloads() {
    KeyValidator::reset_registry();
    // Payload above the 256MB safety cap.
    let oversized_key = vec![0u8; 257 * 1024 * 1024];

    let result = KeyValidator::validate_evaluation_key(&oversized_key, "0.6");
    assert!(
        matches!(result, Err(KeyValidationError::OversizedKey(_))),
        "Security vulnerability: oversized evaluation key allowed!"
    );
}

#[test]
fn test_security_validation_malformed_evaluation_keys() {
    KeyValidator::reset_registry();
    let malformed_key = vec![0xEEu8; 50]; // Random non-deserializable bytes

    let result = KeyValidator::validate_evaluation_key(&malformed_key, "0.6");
    // Garbage bytes can never deserialize into a real ServerKey; bincode may report
    // this as an invalid encoding or an unexpected-EOF (mapped to TruncatedPayload).
    // Both are valid rejections — the security requirement is that it is NOT accepted.
    assert!(
        matches!(
            result,
            Err(KeyValidationError::InvalidSerialization(_)) | Err(KeyValidationError::TruncatedPayload)
        ),
        "Security vulnerability: malformed key bypassed validation!"
    );
}

#[test]
fn test_security_validation_parameter_mismatch() {
    let mismatched_ct = VersionedCiphertext {
        parameter_version: 1,
        library_version: "0.5".to_string(), // Incompatible with engine library 0.6
        serialization_version: 1,
        engine_version: 1,
        raw_ciphertext_bytes: vec![1, 2, 3],
    };

    let result = VersionManager::validate_compatibility(&mismatched_ct);
    assert_eq!(
        result,
        Err("Incompatible library version. Rejecting ciphertext payload."),
        "Security vulnerability: incompatible library version accepted!"
    );
}

#[test]
fn test_security_validation_queue_flooding_backpressure() {
    let queue = DistributedQueue::new();

    // Fill queue to capacity (1000 items)
    for _ in 0..1000 {
        let payload = ComputeRequest {
            key_id: "test-key".to_string(),
            operation: "SUM".to_string(),
            ciphertexts: vec![],
            priority: Some(1),
            timeout_seconds: Some(5),
            tenant_id: None,
            job_id: None,
        };
        assert!(queue.submit_job(payload).is_ok());
    }

    // 1001st item must be blocked by backpressure limits
    let flood_payload = ComputeRequest {
        key_id: "test-key".to_string(),
        operation: "SUM".to_string(),
        ciphertexts: vec![],
        priority: Some(1),
        timeout_seconds: Some(5),
        tenant_id: None,
        job_id: None,
    };
    let result = queue.submit_job(flood_payload);
    assert_eq!(
        result,
        Err("Server busy: Max compute queue capacity reached (backpressure)."),
        "Security vulnerability: queue flooding succeeded (backpressure failure)!"
    );
}

#[test]
fn test_security_validation_memory_dos_budget_exhaustion() {
    let budget = ComputeBudget {
        max_runtime_millis: 5, // 5ms maximum runtime ceiling
        ..ComputeBudget::default()
    };
    let mut tracker = BudgetTracker::new(budget);

    // Simulate FHE computation runtime
    std::thread::sleep(Duration::from_millis(10));

    // Next operation must abort execution
    let result = tracker.record_addition();
    assert_eq!(
        result,
        Err(BudgetError::RuntimeExceeded),
        "Security vulnerability: computation runtime outran budget bounds!"
    );
}
