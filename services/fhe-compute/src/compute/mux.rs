use crate::compute::serialization::{
    deserialize_from_bool, deserialize_from_uint32, serialize_to_uint32,
};
use crate::compute::types::{EncryptedBool, EncryptedUint32, MuxEngine};
use tfhe::prelude::*;
use tfhe::{FheBool, FheUint32};

/// Zama TFHE-rs implementation of the MuxEngine trait.
pub struct ZamaMuxEngine;

impl MuxEngine for ZamaMuxEngine {
    fn select(
        &self,
        condition: &EncryptedBool,
        true_value: &EncryptedUint32,
        false_value: &EncryptedUint32,
    ) -> Result<EncryptedUint32, String> {
        let cond: FheBool = deserialize_from_bool(condition)?;
        let ct_true: FheUint32 = deserialize_from_uint32(true_value)?;
        let ct_false: FheUint32 = deserialize_from_uint32(false_value)?;

        let result = cond.if_then_else(&ct_true, &ct_false);
        serialize_to_uint32(&result)
    }
}
