use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, Duration};
use zeroize::Zeroize;
use tracing::{info, warn};
use lazy_static::lazy_static;

/// Zeroizable wrapper for private cryptographic key material.
/// Ensures secret keys are securely wiped from RAM when dropped.
pub struct SecretKeyMaterial {
    pub raw_bytes: Vec<u8>,
}

impl Zeroize for SecretKeyMaterial {
    fn zeroize(&mut self) {
        self.raw_bytes.zeroize();
    }
}

impl Drop for SecretKeyMaterial {
    fn drop(&mut self) {
        self.zeroize();
        info!("SecretKeyMaterial dropped: memory securely zeroized");
    }
}

impl SecretKeyMaterial {
    pub fn new(bytes: Vec<u8>) -> Self {
        #[cfg(unix)]
        {
            // Lock RAM memory to prevent swapping secret keys to disk on Linux/macOS
            unsafe {
                libc::mlock(bytes.as_ptr() as *const libc::c_void, bytes.len());
            }
        }
        Self { raw_bytes: bytes }
    }
}

#[derive(Clone)]
pub struct CachedKey {
    pub key_id: String,
    pub evaluation_key: Vec<u8>,
    pub expires_at: SystemTime,
}

pub struct KeyLifecycleManager {
    cache: Mutex<HashMap<String, CachedKey>>,
    revocation_list: Mutex<HashMap<String, SystemTime>>,
}

lazy_static! {
    pub static ref KEY_LIFECYCLE_MANAGER: Arc<KeyLifecycleManager> = Arc::new(KeyLifecycleManager::new());
}

impl KeyLifecycleManager {
    pub fn new() -> Self {
        Self {
            cache: Mutex::new(HashMap::new()),
            revocation_list: Mutex::new(HashMap::new()),
        }
    }

    /// Caches an EvaluationKey with a specified TTL (Time to Live)
    pub fn cache_evaluation_key(&self, key_id: String, evaluation_key: Vec<u8>, ttl: Duration) {
        let expires_at = SystemTime::now() + ttl;
        let cached = CachedKey {
            key_id: key_id.clone(),
            evaluation_key,
            expires_at,
        };

        let mut cache = self.cache.lock().unwrap();
        cache.insert(key_id.clone(), cached);
        info!("EvaluationKey {} cached successfully. TTL={:?}", key_id, ttl);
    }

    /// Retrieves an EvaluationKey if active, unexpired, and not revoked
    pub fn get_evaluation_key(&self, key_id: &str) -> Option<Vec<u8>> {
        // 1. Check revocation list
        {
            let rev_list = self.revocation_list.lock().unwrap();
            if rev_list.contains_key(key_id) {
                warn!("Blocked access to revoked EvaluationKey {}", key_id);
                return None;
            }
        }

        // 2. Fetch and check expiration
        let mut cache = self.cache.lock().unwrap();
        if let Some(cached) = cache.get(key_id) {
            if SystemTime::now() < cached.expires_at {
                return Some(cached.evaluation_key.clone());
            } else {
                info!("Evicted expired EvaluationKey {} from cache", key_id);
                cache.remove(key_id);
            }
        }
        None
    }

    /// Revokes an EvaluationKey immediately
    pub fn revoke_key(&self, key_id: String) {
        {
            let mut rev_list = self.revocation_list.lock().unwrap();
            rev_list.insert(key_id.clone(), SystemTime::now());
        }

        // Evict from active cache
        let mut cache = self.cache.lock().unwrap();
        cache.remove(&key_id);
        warn!("EvaluationKey {} has been revoked", key_id);
    }

    /// Cleans up all expired keys in cache (eviction sweep)
    pub fn prune_expired_keys(&self) {
        let now = SystemTime::now();
        let mut cache = self.cache.lock().unwrap();
        cache.retain(|_id, cached| {
            if now < cached.expires_at {
                true
            } else {
                info!("Swept expired key {} from cache", cached.key_id);
                false
            }
        });
    }
}
