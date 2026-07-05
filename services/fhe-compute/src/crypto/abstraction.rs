use serde::{Deserialize, Serialize};
use tfhe::prelude::*;

/// High-level, backend-independent FHE Cryptosystem interface.
/// Follows Dependency Inversion to ensure callers depend only on this contract.
pub trait FheCryptosystem {
    type ClientKey;
    type ServerKey;
    type PublicKey;
    type CiphertextUint32;
    type CiphertextBool;

    // --- Key Management ---
    fn generate_keys(&self) -> (Self::ClientKey, Self::ServerKey);
    fn get_public_key(&self, client_key: &Self::ClientKey) -> Self::PublicKey;

    // --- Encryption / Decryption ---
    fn encrypt(&self, value: u32, client_key: &Self::ClientKey) -> Result<Self::CiphertextUint32, String>;
    fn decrypt(&self, ct: &Self::CiphertextUint32, client_key: &Self::ClientKey) -> Result<u32, String>;
    
    fn encrypt_bool(&self, value: bool, client_key: &Self::ClientKey) -> Result<Self::CiphertextBool, String>;
    fn decrypt_bool(&self, ct: &Self::CiphertextBool, client_key: &Self::ClientKey) -> Result<bool, String>;

    // --- Serialization ---
    fn serialize_uint32(&self, ct: &Self::CiphertextUint32) -> Result<Vec<u8>, String>;
    fn deserialize_uint32(&self, bytes: &[u8]) -> Result<Self::CiphertextUint32, String>;
    
    fn serialize_bool(&self, ct: &Self::CiphertextBool) -> Result<Vec<u8>, String>;
    fn deserialize_bool(&self, bytes: &[u8]) -> Result<Self::CiphertextBool, String>;

    // --- Homomorphic Evaluation ---
    fn add(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String>;
    fn multiply(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String>;
    fn eq(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String>;
    fn gt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String>;
    fn lt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String>;
    fn mux(&self, cond: &Self::CiphertextBool, true_val: &Self::CiphertextUint32, false_val: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String>;
}

// =========================================================================
// 1. ZAMA TFHE ENGINE IMPLEMENTATION
// =========================================================================
pub struct TFHEEngine;

impl FheCryptosystem for TFHEEngine {
    type ClientKey = tfhe::ClientKey;
    type ServerKey = tfhe::ServerKey;
    type PublicKey = tfhe::CompactPublicKey;
    type CiphertextUint32 = tfhe::FheUint32;
    type CiphertextBool = tfhe::FheBool;

    fn generate_keys(&self) -> (Self::ClientKey, Self::ServerKey) {
        let config = tfhe::ConfigBuilder::default().build();
        let client_key = tfhe::ClientKey::generate(config);
        let server_key = tfhe::ServerKey::new(&client_key);
        (client_key, server_key)
    }

    fn get_public_key(&self, client_key: &Self::ClientKey) -> Self::PublicKey {
        tfhe::CompactPublicKey::new(client_key)
    }

    fn encrypt(&self, value: u32, client_key: &Self::ClientKey) -> Result<Self::CiphertextUint32, String> {
        tfhe::FheUint32::try_encrypt(value, client_key).map_err(|e| e.to_string())
    }

    fn decrypt(&self, ct: &Self::CiphertextUint32, client_key: &Self::ClientKey) -> Result<u32, String> {
        Ok(ct.decrypt(client_key))
    }

    fn encrypt_bool(&self, value: bool, client_key: &Self::ClientKey) -> Result<Self::CiphertextBool, String> {
        tfhe::FheBool::try_encrypt(value, client_key).map_err(|e| e.to_string())
    }

    fn decrypt_bool(&self, ct: &Self::CiphertextBool, client_key: &Self::ClientKey) -> Result<bool, String> {
        Ok(ct.decrypt(client_key))
    }

    fn serialize_uint32(&self, ct: &Self::CiphertextUint32) -> Result<Vec<u8>, String> {
        bincode::serialize(ct).map_err(|e| e.to_string())
    }

    fn deserialize_uint32(&self, bytes: &[u8]) -> Result<Self::CiphertextUint32, String> {
        bincode::deserialize(bytes).map_err(|e| e.to_string())
    }

    fn serialize_bool(&self, ct: &Self::CiphertextBool) -> Result<Vec<u8>, String> {
        bincode::serialize(ct).map_err(|e| e.to_string())
    }

    fn deserialize_bool(&self, bytes: &[u8]) -> Result<Self::CiphertextBool, String> {
        bincode::deserialize(bytes).map_err(|e| e.to_string())
    }

    fn add(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(a + b)
    }

    fn multiply(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(a * b)
    }

    fn eq(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(a.eq(b))
    }

    fn gt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(a.gt(b))
    }

    fn lt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(a.lt(b))
    }

    fn mux(&self, cond: &Self::CiphertextBool, true_val: &Self::CiphertextUint32, false_val: &Self::CiphertextUint32, server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        tfhe::set_server_key(server_key.clone());
        Ok(cond.if_then_else(true_val, false_val))
    }
}

// =========================================================================
// 2. MOCK ENGINE IMPLEMENTATION (Saves CPU during local integration testing)
// =========================================================================
pub struct MockEngine;

#[derive(Serialize, Deserialize, Clone)]
pub struct MockClientKey {
    pub seed: u64,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct MockServerKey {
    pub active: bool,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct MockPublicKey {
    pub finger: String,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct MockCiphertextUint32 {
    pub val: u32,
}

#[derive(Serialize, Deserialize, Clone)]
pub struct MockCiphertextBool {
    pub val: bool,
}

impl FheCryptosystem for MockEngine {
    type ClientKey = MockClientKey;
    type ServerKey = MockServerKey;
    type PublicKey = MockPublicKey;
    type CiphertextUint32 = MockCiphertextUint32;
    type CiphertextBool = MockCiphertextBool;

    fn generate_keys(&self) -> (Self::ClientKey, Self::ServerKey) {
        (MockClientKey { seed: 12345 }, MockServerKey { active: true })
    }

    fn get_public_key(&self, _client_key: &Self::ClientKey) -> Self::PublicKey {
        MockPublicKey { finger: "mock-fingerprint".to_string() }
    }

    fn encrypt(&self, value: u32, _client_key: &Self::ClientKey) -> Result<Self::CiphertextUint32, String> {
        Ok(MockCiphertextUint32 { val: value })
    }

    fn decrypt(&self, ct: &Self::CiphertextUint32, _client_key: &Self::ClientKey) -> Result<u32, String> {
        Ok(ct.val)
    }

    fn encrypt_bool(&self, value: bool, _client_key: &Self::ClientKey) -> Result<Self::CiphertextBool, String> {
        Ok(MockCiphertextBool { val: value })
    }

    fn decrypt_bool(&self, ct: &Self::CiphertextBool, _client_key: &Self::ClientKey) -> Result<bool, String> {
        Ok(ct.val)
    }

    fn serialize_uint32(&self, ct: &Self::CiphertextUint32) -> Result<Vec<u8>, String> {
        bincode::serialize(ct).map_err(|e| e.to_string())
    }

    fn deserialize_uint32(&self, bytes: &[u8]) -> Result<Self::CiphertextUint32, String> {
        bincode::deserialize(bytes).map_err(|e| e.to_string())
    }

    fn serialize_bool(&self, ct: &Self::CiphertextBool) -> Result<Vec<u8>, String> {
        bincode::serialize(ct).map_err(|e| e.to_string())
    }

    fn deserialize_bool(&self, bytes: &[u8]) -> Result<Self::CiphertextBool, String> {
        bincode::deserialize(bytes).map_err(|e| e.to_string())
    }

    fn add(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        Ok(MockCiphertextUint32 { val: a.val + b.val })
    }

    fn multiply(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        Ok(MockCiphertextUint32 { val: a.val * b.val })
    }

    fn eq(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        Ok(MockCiphertextBool { val: a.val == b.val })
    }

    fn gt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        Ok(MockCiphertextBool { val: a.val > b.val })
    }

    fn lt(&self, a: &Self::CiphertextUint32, b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        Ok(MockCiphertextBool { val: a.val < b.val })
    }

    fn mux(&self, cond: &Self::CiphertextBool, true_val: &Self::CiphertextUint32, false_val: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        if cond.val {
            Ok(true_val.clone())
        } else {
            Ok(false_val.clone())
        }
    }
}

// =========================================================================
// 3. FUTURE ENGINE PLACEHOLDER (e.g. OpenFHE integration skeleton)
// =========================================================================
pub struct FutureEngine;

pub struct FutureClientKey;
pub struct FutureServerKey;
pub struct FuturePublicKey;
pub struct FutureCiphertextUint32;
pub struct FutureCiphertextBool;

impl FheCryptosystem for FutureEngine {
    type ClientKey = FutureClientKey;
    type ServerKey = FutureServerKey;
    type PublicKey = FuturePublicKey;
    type CiphertextUint32 = FutureCiphertextUint32;
    type CiphertextBool = FutureCiphertextBool;

    fn generate_keys(&self) -> (Self::ClientKey, Self::ServerKey) {
        todo!("Future FHE engine integration pending deployment")
    }

    fn get_public_key(&self, _client_key: &Self::ClientKey) -> Self::PublicKey {
        todo!()
    }

    fn encrypt(&self, _value: u32, _client_key: &Self::ClientKey) -> Result<Self::CiphertextUint32, String> {
        todo!()
    }

    fn decrypt(&self, _ct: &Self::CiphertextUint32, _client_key: &Self::ClientKey) -> Result<u32, String> {
        todo!()
    }

    fn encrypt_bool(&self, _value: bool, _client_key: &Self::ClientKey) -> Result<Self::CiphertextBool, String> {
        todo!()
    }

    fn decrypt_bool(&self, _ct: &Self::CiphertextBool, _client_key: &Self::ClientKey) -> Result<bool, String> {
        todo!()
    }

    fn serialize_uint32(&self, _ct: &Self::CiphertextUint32) -> Result<Vec<u8>, String> {
        todo!()
    }

    fn deserialize_uint32(&self, _bytes: &[u8]) -> Result<Self::CiphertextUint32, String> {
        todo!()
    }

    fn serialize_bool(&self, _ct: &Self::CiphertextBool) -> Result<Vec<u8>, String> {
        todo!()
    }

    fn deserialize_bool(&self, _bytes: &[u8]) -> Result<Self::CiphertextBool, String> {
        todo!()
    }

    fn add(&self, _a: &Self::CiphertextUint32, _b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        todo!()
    }

    fn multiply(&self, _a: &Self::CiphertextUint32, _b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        todo!()
    }

    fn eq(&self, _a: &Self::CiphertextUint32, _b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        todo!()
    }

    fn gt(&self, _a: &Self::CiphertextUint32, _b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        todo!()
    }

    fn lt(&self, _a: &Self::CiphertextUint32, _b: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextBool, String> {
        todo!()
    }

    fn mux(&self, _cond: &Self::CiphertextBool, _true_val: &Self::CiphertextUint32, _false_val: &Self::CiphertextUint32, _server_key: &Self::ServerKey) -> Result<Self::CiphertextUint32, String> {
        todo!()
    }
}
