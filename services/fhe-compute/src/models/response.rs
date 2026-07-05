use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct KeyGenResponse {
    pub parameters_id: String,
    pub serialized_parameters: String,
    /// SHA-256 (hex) of the evaluation key — non-secret, mirrored into
    /// `fhe_key_metadata.public_fingerprint` by the proxy. Empty for the mock path.
    #[serde(default)]
    pub public_fingerprint: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ComputeResponse {
    pub result_ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MemoryScore {
    pub id: String,
    pub encrypted_score: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MemorySearchResponse {
    pub scores: Vec<MemoryScore>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PolicyEvaluateResponse {
    pub masked_encrypted_aes_key: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct JobStatusResponse {
    pub job_id: String,
    pub status: String,
    pub progress: f32,
    pub result: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct HealthResponse {
    pub status: String,
    pub uptime_seconds: u64,
    pub ram_used_bytes: u64,
    pub ram_total_bytes: u64,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct EncryptResponse {
    pub ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct DecryptResponse {
    pub value: u32,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct CompareResponse {
    pub result_ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MuxResponse {
    pub result_ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SimilarityResponse {
    pub result_ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PactEvaluateResponse {
    /// Base64 of an encrypted boolean (`FheBool`); decryptable only with the
    /// pact key, true iff the two parties chose each other.
    pub encrypted_match: String,
}
