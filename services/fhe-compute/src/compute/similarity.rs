use crate::compute::serialization::{deserialize_from_uint32, serialize_to_uint32};
use crate::compute::types::{EncryptedUint32, SimilarityEngine};
use tfhe::FheUint32;
use tfhe::prelude::*;

/// Zama TFHE-rs implementation of the SimilarityEngine trait.
pub struct ZamaSimilarityEngine;

impl SimilarityEngine for ZamaSimilarityEngine {
    fn dot_product(
        &self,
        query: &[EncryptedUint32],
        memory: &[EncryptedUint32],
    ) -> Result<EncryptedUint32, String> {
        if query.len() != memory.len() {
            return Err("Vector dimensions mismatch during similarity computation".to_string());
        }

        if query.is_empty() {
            return Err("Vector is empty during similarity computation".to_string());
        }

        // 1. Initialize result with the first coordinates product
        let q_0: FheUint32 = deserialize_from_uint32(&query[0])?;
        let m_0: FheUint32 = deserialize_from_uint32(&memory[0])?;
        let mut sum_ct = &q_0 * &m_0;

        // 2. Accumulate coordinates products
        for i in 1..query.len() {
            let q_i: FheUint32 = deserialize_from_uint32(&query[i])?;
            let m_i: FheUint32 = deserialize_from_uint32(&memory[i])?;
            let prod = &q_i * &m_i;
            sum_ct = &sum_ct + &prod;
        }

        serialize_to_uint32(&sum_ct)
    }
}
