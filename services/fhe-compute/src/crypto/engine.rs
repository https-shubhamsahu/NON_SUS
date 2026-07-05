use base64::Engine as _;
use sha2::{Digest, Sha256};
use tracing::info;

/// Protocol/versioning constants embedded in every parameter fingerprint so
/// clients and workers can reject incompatible ciphertexts (see versioning.rs).
pub const PARAM_VERSION: &str = "v1";
pub const TFHE_VERSION: &str = "0.6";
pub const SERIALIZATION_VERSION: &str = "v1";
pub const PROTOCOL_VERSION: &str = "v1";

/// Produces a stable, non-secret fingerprint of the parameter set for the given
/// security level. A SHA-256 digest of the version tuple is deterministic and
/// safe to hand to clients — it identifies parameters without revealing keys.
///
/// This replaces the previous static stub. It does NOT expose secret material:
/// a hash of public version metadata cannot reconstruct any key.
pub fn initialize_parameters(security_level: u32, parameter_set: &str) -> String {
    info!(
        "Initializing TFHE parameters: level={}, set={}",
        security_level, parameter_set
    );

    let canonical = format!(
        "TFHE|sec={security_level}|set={parameter_set}|param={PARAM_VERSION}|tfhe={TFHE_VERSION}|ser={SERIALIZATION_VERSION}|proto={PROTOCOL_VERSION}"
    );

    let mut hasher = Sha256::new();
    hasher.update(canonical.as_bytes());
    let digest = hasher.finalize();

    base64::prelude::BASE64_STANDARD.encode(digest)
}

/// Lightweight structural check on an incoming ciphertext payload: it must be
/// valid base64 and non-empty. Deep validation (TFHE deserialization, parameter
/// compatibility) happens in the compute/validation layer before evaluation.
pub fn verify_ciphertext_integrity(payload: &str) -> bool {
    if payload.is_empty() {
        return false;
    }
    base64::prelude::BASE64_STANDARD.decode(payload).is_ok()
}
