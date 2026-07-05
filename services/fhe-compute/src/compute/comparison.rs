use crate::compute::serialization::{deserialize_from_uint32, serialize_to_bool};
use crate::compute::types::{ComparisonEngine, EncryptedBool, EncryptedUint32};
use tfhe::FheUint32;
use tfhe::prelude::*;

/// Zama TFHE-rs implementation of the ComparisonEngine trait.
pub struct ZamaComparisonEngine;

impl ComparisonEngine for ZamaComparisonEngine {
    fn eq(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String> {
        let ct_a: FheUint32 = deserialize_from_uint32(a)?;
        let ct_b: FheUint32 = deserialize_from_uint32(b)?;

        let result = ct_a.eq(&ct_b);
        serialize_to_bool(&result)
    }

    fn gt(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String> {
        let ct_a: FheUint32 = deserialize_from_uint32(a)?;
        let ct_b: FheUint32 = deserialize_from_uint32(b)?;

        let result = ct_a.gt(&ct_b);
        serialize_to_bool(&result)
    }

    fn lt(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedBool, String> {
        let ct_a: FheUint32 = deserialize_from_uint32(a)?;
        let ct_b: FheUint32 = deserialize_from_uint32(b)?;

        let result = ct_a.lt(&ct_b);
        serialize_to_bool(&result)
    }
}
