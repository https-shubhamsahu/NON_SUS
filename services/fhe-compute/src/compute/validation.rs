use crate::compute::serialization::{deserialize_from_bool, deserialize_from_uint32};
use crate::compute::types::{EncryptedBool, EncryptedUint32, ValidationEngine};
use tfhe::FheBool;
use tfhe::FheUint32;

/// Zama TFHE-rs implementation of the ValidationEngine trait.
pub struct ZamaValidationEngine;

impl ValidationEngine for ZamaValidationEngine {
    fn validate_ciphertext(&self, ct: &EncryptedUint32) -> bool {
        // Attempt deserialization to verify structure integrity
        let decoded: Result<FheUint32, _> = deserialize_from_uint32(ct);
        decoded.is_ok()
    }

    fn validate_bool_ciphertext(&self, ct: &EncryptedBool) -> bool {
        // Attempt deserialization to verify structure integrity
        let decoded: Result<FheBool, _> = deserialize_from_bool(ct);
        decoded.is_ok()
    }
}
