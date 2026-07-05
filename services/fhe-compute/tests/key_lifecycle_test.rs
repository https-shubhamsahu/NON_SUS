use fhe_compute::keys::{SecretKeyMaterial, KeyLifecycleManager};
use std::time::{Duration, SystemTime};

#[test]
fn test_secret_key_material_zeroization() {
    let raw_key = vec![1u8, 2, 3, 4, 5];
    let key_ptr = raw_key.as_ptr();

    {
        let _secret = SecretKeyMaterial::new(raw_key);
        // Under normal scope, values are present in RAM
        unsafe {
            assert_eq!(*key_ptr.offset(0), 1);
            assert_eq!(*key_ptr.offset(4), 5);
        }
    }

    // After drop, the memory has been zeroed out securely by Zeroize trait
    unsafe {
        assert_eq!(*key_ptr.offset(0), 0);
        assert_eq!(*key_ptr.offset(4), 0);
    }
}

#[test]
fn test_key_lifecycle_caching_and_expiration() {
    let manager = KeyLifecycleManager::new();
    let key_id = "test-key-123".to_string();
    let key_data = vec![42u8; 100];

    // Cache key for 500ms
    manager.cache_evaluation_key(key_id.clone(), key_data.clone(), Duration::from_millis(500));

    // Retrieval before expiration
    let fetched = manager.get_evaluation_key(&key_id);
    assert!(fetched.is_some());
    assert_eq!(fetched.unwrap(), key_data);

    // Sleep until expiration
    std::thread::sleep(Duration::from_millis(600));

    // Retrieval after expiration must be evicted (None)
    let expired = manager.get_evaluation_key(&key_id);
    assert!(expired.is_none());
}

#[test]
fn test_key_revocation() {
    let manager = KeyLifecycleManager::new();
    let key_id = "revocation-key-abc".to_string();
    let key_data = vec![99u8; 100];

    manager.cache_evaluation_key(key_id.clone(), key_data.clone(), Duration::from_secs(60));

    // Revoke key
    manager.revoke_key(key_id.clone());

    // Retrieval must fail
    let revoked = manager.get_evaluation_key(&key_id);
    assert!(revoked.is_none());
}
