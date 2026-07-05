use crate::compute::serialization::{deserialize_from_uint32, serialize_to_uint32};
use crate::compute::types::{ArithmeticEngine, EncryptedUint32};
use tfhe::FheUint32;
use tfhe::prelude::*;

/// Zama TFHE-rs implementation of the ArithmeticEngine trait.
pub struct ZamaArithmeticEngine;

impl ArithmeticEngine for ZamaArithmeticEngine {
    fn add(&self, a: &EncryptedUint32, b: &EncryptedUint32) -> Result<EncryptedUint32, String> {
        let ct_a: FheUint32 = deserialize_from_uint32(a)?;
        let ct_b: FheUint32 = deserialize_from_uint32(b)?;

        let result = &ct_a + &ct_b;
        serialize_to_uint32(&result)
    }

    fn multiply(
        &self,
        a: &EncryptedUint32,
        b: &EncryptedUint32,
    ) -> Result<EncryptedUint32, String> {
        let ct_a: FheUint32 = deserialize_from_uint32(a)?;
        let ct_b: FheUint32 = deserialize_from_uint32(b)?;

        let result = &ct_a * &ct_b;
        serialize_to_uint32(&result)
    }
}
