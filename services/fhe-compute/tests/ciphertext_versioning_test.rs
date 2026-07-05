use fhe_compute::compute::{VersionedCiphertext, VersionManager};

#[test]
fn test_valid_current_ciphertext() {
    let ct = VersionedCiphertext {
        parameter_version: 1,
        library_version: "0.6".to_string(),
        serialization_version: 1,
        engine_version: 1,
        raw_ciphertext_bytes: vec![1, 2, 3],
    };

    assert!(VersionManager::validate_compatibility(&ct).is_ok());
}

#[test]
fn test_deprecated_migration_successful() {
    let legacy_ct = VersionedCiphertext {
        parameter_version: 0, // Legacy/Deprecated version
        library_version: "0.6".to_string(),
        serialization_version: 1,
        engine_version: 1,
        raw_ciphertext_bytes: vec![4, 5, 6],
    };

    // Compatibility check passes (allows legacy version)
    assert!(VersionManager::validate_compatibility(&legacy_ct).is_ok());

    // Migration upgrades parameter version to current (1)
    let migration_res = VersionManager::migrate_ciphertext(legacy_ct);
    assert!(migration_res.is_ok());
    let migrated_ct = migration_res.unwrap();
    assert_eq!(migrated_ct.parameter_version, 1);
    assert_eq!(migrated_ct.raw_ciphertext_bytes, vec![4, 5, 6]);
}

#[test]
fn test_rejects_incompatible_library_version() {
    let ct = VersionedCiphertext {
        parameter_version: 1,
        library_version: "0.5".to_string(), // Expected 0.6
        serialization_version: 1,
        engine_version: 1,
        raw_ciphertext_bytes: vec![1],
    };

    let result = VersionManager::validate_compatibility(&ct);
    assert_eq!(result, Err("Incompatible library version. Rejecting ciphertext payload."));
}

#[test]
fn test_rejects_future_parameter_version() {
    let ct = VersionedCiphertext {
        parameter_version: 2, // Current is 1
        library_version: "0.6".to_string(),
        serialization_version: 1,
        engine_version: 1,
        raw_ciphertext_bytes: vec![1],
    };

    let result = VersionManager::validate_compatibility(&ct);
    assert_eq!(result, Err("Unsupported future parameter version."));
}

#[test]
fn test_rejects_future_serialization_version() {
    let ct = VersionedCiphertext {
        parameter_version: 1,
        library_version: "0.6".to_string(),
        serialization_version: 2, // Current is 1
        engine_version: 1,
        raw_ciphertext_bytes: vec![1],
    };

    let result = VersionManager::validate_compatibility(&ct);
    assert_eq!(result, Err("Unsupported future serialization version."));
}

#[test]
fn test_rejects_future_engine_version() {
    let ct = VersionedCiphertext {
        parameter_version: 1,
        library_version: "0.6".to_string(),
        serialization_version: 1,
        engine_version: 2, // Current is 1
        raw_ciphertext_bytes: vec![1],
    };

    let result = VersionManager::validate_compatibility(&ct);
    assert_eq!(result, Err("Unsupported future engine version."));
}
