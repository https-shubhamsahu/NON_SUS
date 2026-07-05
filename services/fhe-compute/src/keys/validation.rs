use sha2::{Sha256, Digest};
use std::collections::HashSet;
use std::sync::Mutex;
use lazy_static::lazy_static;
use tracing::{info, warn};

// Safety limit: 256MB max key size to prevent RAM exhaustion DOS.
// Must sit above a real tfhe ServerKey (~112MB with default parameters) while
// still rejecting absurdly large payloads.
const MAX_KEY_SIZE: usize = 256 * 1024 * 1024;
const CURRENT_TFHE_VERSION: &str = "0.6";

#[derive(Debug, PartialEq, Eq)]
pub enum KeyValidationError {
    OversizedKey(usize),
    InvalidSerialization(String),
    CorruptedPayload,
    UnsupportedParameterSet,
    VersionMismatch { expected: String, found: String },
    DuplicateKey(String),
    TruncatedPayload,
}

impl std::fmt::Display for KeyValidationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            KeyValidationError::OversizedKey(sz) => write!(f, "Evaluation key size exceeds safety limits: {} bytes", sz),
            KeyValidationError::InvalidSerialization(e) => write!(f, "Evaluation key failed deserialization: {}", e),
            KeyValidationError::CorruptedPayload => write!(f, "Evaluation key payload is corrupted"),
            KeyValidationError::UnsupportedParameterSet => write!(f, "Evaluation key parameter set is unsupported"),
            KeyValidationError::VersionMismatch { expected, found } => {
                write!(f, "TFHE version mismatch. Expected {}, found {}", expected, found)
            }
            KeyValidationError::DuplicateKey(hash) => write!(f, "Evaluation key already exists in registry (Hash: {})", hash),
            KeyValidationError::TruncatedPayload => write!(f, "Evaluation key payload is truncated or incomplete"),
        }
    }
}

// Registry to track registered key fingerprints
lazy_static! {
    static ref FINGERPRINT_REGISTRY: Mutex<HashSet<String>> = Mutex::new(HashSet::new());
}

pub struct KeyValidator;

impl KeyValidator {
    /// Resets the validation registry (mainly for testing)
    pub fn reset_registry() {
        let mut registry = FINGERPRINT_REGISTRY.lock().unwrap();
        registry.clear();
    }

    /// Performs enterprise-grade validation checks on a raw FHE Evaluation Key payload.
    /// Returns the computed SHA-256 fingerprint hash on success.
    pub fn validate_evaluation_key(
        raw_key: &[u8],
        declared_version: &str,
    ) -> Result<String, KeyValidationError> {
        // 1. Check size limits
        if raw_key.len() > MAX_KEY_SIZE {
            warn!("Rejected oversized key: {} bytes", raw_key.len());
            return Err(KeyValidationError::OversizedKey(raw_key.len()));
        }

        // 2. Check truncated payloads
        if raw_key.len() < 16 {
            warn!("Rejected truncated key payload: {} bytes", raw_key.len());
            return Err(KeyValidationError::TruncatedPayload);
        }

        // 3. Check version mismatches
        if declared_version != CURRENT_TFHE_VERSION {
            warn!("Rejected version mismatch: declared={}, expected={}", declared_version, CURRENT_TFHE_VERSION);
            return Err(KeyValidationError::VersionMismatch {
                expected: CURRENT_TFHE_VERSION.to_string(),
                found: declared_version.to_string(),
            });
        }

        // 4. Check for payload corruption by attempting deserialization
        // Using tfhe::ServerKey or simulated mock structure depending on the payload structure
        let decoded: Result<tfhe::ServerKey, _> = bincode::deserialize(raw_key);
        if let Err(e) = decoded {
            // Check if corruption looks like standard bincode bounds / truncation failures
            let err_msg = e.to_string();
            if err_msg.contains("io error") || err_msg.contains("unexpected end of file") {
                return Err(KeyValidationError::TruncatedPayload);
            }
            warn!("Failed deserializing evaluation key: {}", err_msg);
            return Err(KeyValidationError::InvalidSerialization(err_msg));
        }

        // 5. Generate SHA-256 fingerprint
        let mut hasher = Sha256::new();
        hasher.update(raw_key);
        let hash_result = hasher.finalize();
        let fingerprint = format!("{:x}", hash_result);

        // 6. Check for duplicate key uploads
        {
            let mut registry = FINGERPRINT_REGISTRY.lock().unwrap();
            if registry.contains(&fingerprint) {
                warn!("Rejected duplicate evaluation key: {}", fingerprint);
                return Err(KeyValidationError::DuplicateKey(fingerprint));
            }
            registry.insert(fingerprint.clone());
        }

        info!("Evaluation key validated successfully. Fingerprint: {}", fingerprint);
        Ok(fingerprint)
    }
}
