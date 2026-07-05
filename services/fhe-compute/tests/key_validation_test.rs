use fhe_compute::keys::{KeyValidator, KeyValidationError};
use tfhe::prelude::*;
use tfhe::{ConfigBuilder, ClientKey, ServerKey};
use proptest::prelude::*;

fn generate_real_evaluation_key() -> Vec<u8> {
    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let server_key = ServerKey::new(&client_key);
    bincode::serialize(&server_key).unwrap()
}

#[test]
fn test_validation_success_on_real_key() {
    KeyValidator::reset_registry();
    let raw_key = generate_real_evaluation_key();

    let result = KeyValidator::validate_evaluation_key(&raw_key, "0.6");
    assert!(result.is_ok());
    let fingerprint = result.unwrap();
    assert_eq!(fingerprint.len(), 64); // SHA-256 hex length
}

#[test]
fn test_validation_rejects_version_mismatch() {
    KeyValidator::reset_registry();
    let raw_key = generate_real_evaluation_key();

    let result = KeyValidator::validate_evaluation_key(&raw_key, "0.5");
    assert_eq!(
        result,
        Err(KeyValidationError::VersionMismatch {
            expected: "0.6".to_string(),
            found: "0.5".to_string()
        })
    );
}

#[test]
fn test_validation_rejects_truncated_payload() {
    KeyValidator::reset_registry();
    let short_key = vec![0u8; 8]; // Below 16 bytes limit

    let result = KeyValidator::validate_evaluation_key(&short_key, "0.6");
    assert_eq!(result, Err(KeyValidationError::TruncatedPayload));
}

#[test]
fn test_validation_rejects_oversized_payload() {
    KeyValidator::reset_registry();
    // Safety size limit is 256MB; pass a payload above it to trigger rejection.
    let large_key = vec![0u8; 257 * 1024 * 1024];

    let result = KeyValidator::validate_evaluation_key(&large_key, "0.6");
    assert!(matches!(result, Err(KeyValidationError::OversizedKey(_))));
}

#[test]
fn test_validation_rejects_duplicate_key() {
    KeyValidator::reset_registry();
    let raw_key = generate_real_evaluation_key();

    // First upload succeeds
    let first_res = KeyValidator::validate_evaluation_key(&raw_key, "0.6");
    assert!(first_res.is_ok());

    // Second upload fails as duplicate
    let second_res = KeyValidator::validate_evaluation_key(&raw_key, "0.6");
    assert!(matches!(second_res, Err(KeyValidationError::DuplicateKey(_))));
}

#[test]
fn test_validation_rejects_corrupted_serialization() {
    KeyValidator::reset_registry();
    // Create random non-deserializable 100 bytes payload
    let corrupt_key = vec![0xAAu8; 100];

    let result = KeyValidator::validate_evaluation_key(&corrupt_key, "0.6");
    // Depending on the garbage byte pattern, bincode may surface the failure as an
    // invalid encoding or as an unexpected-EOF (which the validator maps to
    // TruncatedPayload). Both are valid rejections of a corrupted key.
    assert!(matches!(
        result,
        Err(KeyValidationError::InvalidSerialization(_)) | Err(KeyValidationError::TruncatedPayload)
    ));
}

// Proptest fuzzing to verify validator robustness against arbitrary input payloads
proptest! {
    #[test]
    fn test_fuzz_validator_does_not_panic(ref data in any::<Vec<u8>>()) {
        KeyValidator::reset_registry();
        // The validator must return an error (or occasionally success if it matches valid layout by chance) but MUST NEVER panic.
        let _ = KeyValidator::validate_evaluation_key(data, "0.6");
    }
}
