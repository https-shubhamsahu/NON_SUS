use crate::compute::types::{EncryptedBool, EncryptedUint32};
use serde::Serialize;
use serde::de::DeserializeOwned;

/// Serializes a concrete FHE type to the abstract `EncryptedUint32` wrapper.
pub fn serialize_to_uint32<T: Serialize>(value: &T) -> Result<EncryptedUint32, String> {
    bincode::serialize(value)
        .map(|raw_bytes| EncryptedUint32 { raw_bytes })
        .map_err(|e| format!("Serialization error: {}", e))
}

/// Deserializes a concrete FHE type from the abstract `EncryptedUint32` wrapper.
pub fn deserialize_from_uint32<T: DeserializeOwned>(
    wrapper: &EncryptedUint32,
) -> Result<T, String> {
    bincode::deserialize(&wrapper.raw_bytes).map_err(|e| format!("Deserialization error: {}", e))
}

/// Serializes a concrete FHE type to the abstract `EncryptedBool` wrapper.
pub fn serialize_to_bool<T: Serialize>(value: &T) -> Result<EncryptedBool, String> {
    bincode::serialize(value)
        .map(|raw_bytes| EncryptedBool { raw_bytes })
        .map_err(|e| format!("Serialization error: {}", e))
}

/// Deserializes a concrete FHE type from the abstract `EncryptedBool` wrapper.
pub fn deserialize_from_bool<T: DeserializeOwned>(wrapper: &EncryptedBool) -> Result<T, String> {
    bincode::deserialize(&wrapper.raw_bytes).map_err(|e| format!("Deserialization error: {}", e))
}
