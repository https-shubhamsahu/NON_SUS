pub mod arithmetic;
pub mod budget;
pub mod comparison;
pub mod mux;
pub mod pact;
pub mod serialization;
pub mod similarity;
pub mod types;
pub mod validation;
pub mod versioning;

pub use types::{
    ArithmeticEngine, ComparisonEngine, EncryptedBool, EncryptedUint32, MuxEngine,
    SimilarityEngine, ValidationEngine,
};

pub use arithmetic::ZamaArithmeticEngine;
pub use budget::{BudgetError, BudgetTracker, ComputeBudget};
pub use comparison::ZamaComparisonEngine;
pub use mux::ZamaMuxEngine;
pub use pact::homomorphic_mutual_match;
pub use similarity::ZamaSimilarityEngine;
pub use validation::ZamaValidationEngine;
pub use versioning::{VersionManager, VersionedCiphertext};

// ─── Base64 Decoupled API Wrappers for REST Handlers ─────────────────────────

pub fn homomorphic_sum(ciphertexts: &[String]) -> String {
    if ciphertexts.is_empty() {
        return String::new();
    }
    let engine = ZamaArithmeticEngine;
    let mut sum = EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, &ciphertexts[0])
            .unwrap_or_default(),
    };
    for ct in ciphertexts.iter().skip(1) {
        let next = EncryptedUint32 {
            raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, ct)
                .unwrap_or_default(),
        };
        if let Ok(res) = engine.add(&sum, &next) {
            sum = res;
        }
    }
    base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &sum.raw_bytes)
}

pub fn homomorphic_product(ciphertexts: &[String]) -> String {
    if ciphertexts.is_empty() {
        return String::new();
    }
    let engine = ZamaArithmeticEngine;
    let mut prod = EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, &ciphertexts[0])
            .unwrap_or_default(),
    };
    for ct in ciphertexts.iter().skip(1) {
        let next = EncryptedUint32 {
            raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, ct)
                .unwrap_or_default(),
        };
        if let Ok(res) = engine.multiply(&prod, &next) {
            prod = res;
        }
    }
    base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &prod.raw_bytes)
}

pub fn homomorphic_inner_product(query: &[String], memory: &[String]) -> String {
    let engine = ZamaSimilarityEngine;
    let q: Vec<EncryptedUint32> = query
        .iter()
        .map(|ct| EncryptedUint32 {
            raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, ct)
                .unwrap_or_default(),
        })
        .collect();
    let m: Vec<EncryptedUint32> = memory
        .iter()
        .map(|ct| EncryptedUint32 {
            raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, ct)
                .unwrap_or_default(),
        })
        .collect();

    if let Ok(result) = engine.dot_product(&q, &m) {
        base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &result.raw_bytes)
    } else {
        String::new()
    }
}

/// Encodes an inner product request into the existing async job payload shape:
/// first half = query vector, second half = participant/private vector.
pub fn homomorphic_inner_product_split(ciphertexts: &[String]) -> Result<String, String> {
    if ciphertexts.is_empty() || ciphertexts.len() % 2 != 0 {
        return Err("SIMILARITY jobs require an even, non-empty ciphertext vector".to_string());
    }

    let split_at = ciphertexts.len() / 2;
    let result = homomorphic_inner_product(&ciphertexts[..split_at], &ciphertexts[split_at..]);

    if result.is_empty() {
        Err("SIMILARITY computation failed".to_string())
    } else {
        Ok(result)
    }
}

pub fn homomorphic_policy_mux(
    user_clearance: &str,
    required_clearance: u8,
    encrypted_aes_key: &str,
) -> String {
    let mux_engine = ZamaMuxEngine;

    let cond = EncryptedBool {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, user_clearance)
            .unwrap_or_default(),
    };
    let ct_true = EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, encrypted_aes_key)
            .unwrap_or_default(),
    };
    // Dummy key representing 0
    let ct_false = EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, "MASKED_DUMMY_KEY_0")
            .unwrap_or_default(),
    };

    // If clearance check condition matches, return the encrypted key, else dummy key
    if let Ok(result) = mux_engine.select(&cond, &ct_true, &ct_false) {
        base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &result.raw_bytes)
    } else {
        String::new()
    }
}
