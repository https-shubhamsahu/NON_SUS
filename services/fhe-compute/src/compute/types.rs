use serde::{Deserialize, Serialize};

/// Abstract wrapper representing an encrypted 32-bit unsigned integer.
/// Hides the underlying FHE backend implementation types.
#[derive(Clone, Serialize, Deserialize)]
pub struct EncryptedUint32 {
    pub raw_bytes: Vec<u8>,
}

/// Abstract wrapper representing an encrypted boolean value.
/// Hides the underlying FHE backend implementation types.
#[derive(Clone, Serialize, Deserialize)]
pub struct EncryptedBool {
    pub raw_bytes: Vec<u8>,
}

/// Trait defining the contract for homomorphic arithmetic.
/// Allows future replacement with other FHE backends (e.g. OpenFHE, SEAL).
pub trait ArithmeticEngine {
    fn add(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedUint32, String>;
    fn multiply(&self, a: &EncryptedUint32, b: &EncryptedUint32)
    -> Result<EncryptedUint32, String>;
}

/// Trait defining the contract for homomorphic comparisons.
pub trait ComparisonEngine {
    fn eq(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String>;
    fn gt(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String>;
    fn lt(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String>;
}

/// Trait defining the contract for homomorphic multiplexing.
pub trait MuxEngine {
    fn select(
        &self,
        condition: &EncryptedBool,
        true_value: &EncryptedUint32,
        false_value: &EncryptedUint32,
    ) -> Result<EncryptedUint32, String>;
}

/// Trait defining the contract for homomorphic vector similarity checks.
pub trait SimilarityEngine {
    fn dot_product(
        &self,
        query: &[EncryptedUint32],
        memory: &[EncryptedUint32],
    ) -> Result<EncryptedUint32, String>;
}

/// Trait defining the contract for payload integrity validation.
pub trait ValidationEngine {
    fn validate_ciphertext(&self, ct: &EncryptedUint32) -> bool;
    fn validate_bool_ciphertext(&self, ct: &EncryptedBool) -> bool;
}
