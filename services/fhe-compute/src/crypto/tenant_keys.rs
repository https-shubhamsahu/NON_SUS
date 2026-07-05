use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use lazy_static::lazy_static;
use sha2::{Digest, Sha256};
use tracing::info;

use crate::crypto::{FheCryptosystem, TFHEEngine};

/// Live TFHE key material for a single tenant, held in RAM only.
///
/// INTERIM DESIGN: the server currently holds each tenant's `ClientKey` so it
/// can encrypt/decrypt on the caller's behalf, mirroring the previous
/// `MockEngine` behaviour. The long-term design moves encryption and decryption
/// on-device (TFHE WASM/FFI) so the server only ever holds the `ServerKey` and
/// evaluates. Key material is NEVER persisted to disk or written to logs.
pub struct TenantKeys {
    pub client_key: tfhe::ClientKey,
    pub server_key: tfhe::ServerKey,
    /// SHA-256 (hex) of the serialized ServerKey (the public evaluation key).
    /// A hash is NOT secret and cannot reconstruct the key; it is surfaced to
    /// `fhe_key_metadata.public_fingerprint` for integrity checks and to key the
    /// lifecycle row. Empty only if serialization somehow failed.
    pub fingerprint: String,
}

/// Computes the non-secret public fingerprint of an evaluation (server) key.
fn server_key_fingerprint(server_key: &tfhe::ServerKey) -> String {
    match bincode::serialize(server_key) {
        Ok(bytes) => {
            let mut hasher = Sha256::new();
            hasher.update(&bytes);
            format!("{:x}", hasher.finalize())
        }
        Err(_) => String::new(),
    }
}

/// Thread-safe, per-tenant store of live TFHE keys keyed by the `X-Tenant-Id`
/// the `fhe-proxy` Edge Function attaches (the caller's Supabase user id).
pub struct TenantKeyStore {
    keys: Mutex<HashMap<String, Arc<TenantKeys>>>,
}

lazy_static! {
    pub static ref TENANT_KEY_STORE: TenantKeyStore = TenantKeyStore::new();
}

impl TenantKeyStore {
    fn new() -> Self {
        Self { keys: Mutex::new(HashMap::new()) }
    }

    /// Returns the tenant's keys, generating and caching them on first use.
    /// Real TFHE key generation is expensive, so it happens at most once per
    /// tenant per process lifetime unless [`regenerate`](Self::regenerate) is called.
    pub fn get_or_create(&self, tenant_id: &str) -> Arc<TenantKeys> {
        {
            let map = self.keys.lock().unwrap();
            if let Some(existing) = map.get(tenant_id) {
                return existing.clone();
            }
        }
        // Not cached: generate WITHOUT holding the lock (keygen is slow), then
        // insert. `or_insert` resolves the race if another thread beat us to it
        // (the loser's freshly generated keys are simply dropped).
        let fresh = Arc::new(Self::generate());
        let mut map = self.keys.lock().unwrap();
        let keys = map.entry(tenant_id.to_string()).or_insert(fresh).clone();
        info!("TFHE key set ready for tenant (generated on demand)");
        keys
    }

    /// Forces fresh key generation for the tenant (rotation), replacing any
    /// cached keys. Ciphertexts produced under the previous keys become
    /// undecryptable, so callers must re-encrypt after rotating.
    pub fn regenerate(&self, tenant_id: &str) -> Arc<TenantKeys> {
        let keys = Arc::new(Self::generate());
        let mut map = self.keys.lock().unwrap();
        map.insert(tenant_id.to_string(), keys.clone());
        keys
    }

    /// Revokes a tenant's key material, dropping it from memory so subsequent
    /// operations must generate a fresh set. Returns whether keys were present.
    /// (Zeroization of the underlying tfhe key buffers is handled on drop.)
    pub fn revoke(&self, tenant_id: &str) -> bool {
        let removed = self.keys.lock().unwrap().remove(tenant_id).is_some();
        if removed {
            info!("Revoked and dropped TFHE key material for a tenant");
        }
        removed
    }

    /// Whether the tenant already has cached key material.
    pub fn contains(&self, tenant_id: &str) -> bool {
        self.keys.lock().unwrap().contains_key(tenant_id)
    }

    fn generate() -> TenantKeys {
        let engine = TFHEEngine;
        let (client_key, server_key) = engine.generate_keys();
        let fingerprint = server_key_fingerprint(&server_key);
        TenantKeys { client_key, server_key, fingerprint }
    }
}
