use fhe_compute::middleware::replay_protection::ReplayCache;
use std::time::{SystemTime, UNIX_EPOCH};

#[test]
fn test_valid_nonce_verification() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    let result = cache.verify_and_insert("nonce-1", current_time);
    assert!(result.is_ok());
}

#[test]
fn test_duplicate_nonce_blocked() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // First insertion succeeds
    let first = cache.verify_and_insert("nonce-2", current_time);
    assert!(first.is_ok());

    // Duplicate insertion fails
    let second = cache.verify_and_insert("nonce-2", current_time);
    assert_eq!(second, Err("Duplicate request nonce detected. Replay blocked."));
}

#[test]
fn test_clock_drift_too_old_blocked() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // Request from 301 seconds ago (exceeds 300s window)
    let old_timestamp = current_time - 301;

    let result = cache.verify_and_insert("nonce-3", old_timestamp);
    assert_eq!(result, Err("Clock drift limit exceeded. Request expired."));
}

#[test]
fn test_clock_drift_future_blocked() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // Request from 301 seconds in the future
    let future_timestamp = current_time + 301;

    let result = cache.verify_and_insert("nonce-4", future_timestamp);
    assert_eq!(result, Err("Clock drift limit exceeded. Request expired."));
}

#[test]
fn test_pruning_removes_expired_nonces() {
    let cache = ReplayCache::new();
    let current_time = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    // 1. Insert an active nonce
    assert!(cache.verify_and_insert("active-nonce", current_time).is_ok());

    // 2. Mock insert an expired nonce (bypassing window check directly into hashmap for test simulation)
    // Wait, let's just insert a nonce at current_time - 299 seconds, wait 2 seconds, and prune!
    let near_expired_time = current_time - 299;
    assert!(cache.verify_and_insert("dying-nonce", near_expired_time).is_ok());

    // Wait 2 seconds (dying-nonce age becomes 301 seconds)
    std::thread::sleep(std::time::Duration::from_secs(2));

    // Prune expired nonces
    cache.prune();

    // 3. Since dying-nonce is pruned, we should be able to insert it again!
    // If it was not pruned, it would return Duplicate error.
    let re_insert = cache.verify_and_insert("dying-nonce", current_time);
    assert!(re_insert.is_ok(), "Nonce was not pruned correctly: {:?}", re_insert);
}
