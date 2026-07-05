use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct KeyGenRequest {
    pub security_level: u32,
    pub parameter_set: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ComputeRequest {
    pub key_id: String,
    pub operation: String,
    pub ciphertexts: Vec<String>,
    pub priority: Option<u8>,
    pub timeout_seconds: Option<u64>,
    /// Tenant that owns the ciphertexts. Injected by the fhe-proxy (merged into
    /// the body) or derived from the X-Tenant-Id header by the handler; the
    /// async worker uses it to load the right ServerKey before evaluating.
    #[serde(default)]
    pub tenant_id: Option<String>,
    /// Supabase `fhe_compute_jobs` row id mirrored by the fhe-proxy. When set,
    /// the async worker writes result/status back to that row on completion.
    #[serde(default)]
    pub job_id: Option<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MemoryItem {
    pub id: String,
    pub vector: Vec<String>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MemorySearchRequest {
    pub key_id: String,
    pub query_vector: Vec<String>,
    pub memories: Vec<MemoryItem>,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PolicyEvaluateRequest {
    pub key_id: String,
    pub user_encrypted_clearance: String,
    pub doc_required_clearance: u8,
    pub encrypted_aes_key: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct EncryptRequest {
    pub key_id: String,
    pub value: u32,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct DecryptRequest {
    pub key_id: String,
    pub ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct CompareRequest {
    pub key_id: String,
    pub op: String,
    pub ciphertext_a: String,
    pub ciphertext_b: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct MuxRequest {
    pub key_id: String,
    pub condition_ciphertext: String,
    pub true_ciphertext: String,
    pub false_ciphertext: String,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SimilarityRequest {
    pub key_id: String,
    pub query_vector: Vec<String>,
    pub memory_vector: Vec<String>,
}

/// A pairwise pact ("conditional revelation"): two parties' sealed choices under
/// the arena's shared key, plus the two public arena ids. The evaluator returns
/// an encrypted boolean that is true iff the two chose each other.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PactEvaluateRequest {
    /// Shared key context for this pact (the arena the parties belong to).
    pub arena_id: String,
    /// Party A's sealed choice (base64 TFHE ciphertext) and public arena id.
    pub a_choice: String,
    pub a_id: u32,
    /// Party B's sealed choice (base64 TFHE ciphertext) and public arena id.
    pub b_choice: String,
    pub b_id: u32,
}

/// Opens a pact verdict (the encrypted boolean from `/pact/evaluate`) with the
/// arena's pact key. Interim trust model: the server holds the arena key, so
/// the trusted matcher service calls this; post-M10 this decrypt moves on-device.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PactDecryptRequest {
    /// Key context — must be the same arena the verdict was evaluated under.
    pub arena_id: String,
    /// Base64 encrypted boolean returned by `/pact/evaluate`.
    pub encrypted_match: String,
}

/// Seals a choice under an ARENA's shared pact key (not the caller-tenant key
/// that `/encrypt` uses). Used by the trusted matcher service when a member
/// seals; post-M10 sealing moves on-device under the arena public key.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct PactSealRequest {
    /// Key context (the arena the seal belongs to).
    pub arena_id: String,
    /// The picked member's public arena id (plaintext in transit only; never stored).
    pub choice: u32,
}
