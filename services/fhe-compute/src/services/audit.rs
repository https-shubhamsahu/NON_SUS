use serde_json::json;
use tracing::{info, warn};

/// Service to push sanitised FHE security events to the append-only audit ledger database.
pub struct AuditLogger;

impl AuditLogger {
    /// Dispatches a sanitised event to the Supabase RPC ledger or falls back to local traces.
    /// Ensures no plaintext, ciphertexts, or secret keys are leaked in metadata.
    pub async fn log_fhe_event(
        group_id: &str,
        event_type: &str,
        raw_metadata: serde_json::Value,
    ) {
        // 1. Enforce strict data sanitization (remove blacklisted elements)
        let mut clean_metadata = raw_metadata.clone();
        if let Some(map) = clean_metadata.as_object_mut() {
            map.remove("secret_key");
            map.remove("client_key");
            map.remove("server_key");
            map.remove("ciphertext");
            map.remove("result_ciphertext");
            map.remove("ciphertexts");
            map.remove("plaintext");
            map.remove("value");
        }

        // Add standard FHE tags
        if let Some(map) = clean_metadata.as_object_mut() {
            map.insert("fhe_event_marker".to_string(), json!(true));
            map.insert("timestamp_utc".to_string(), json!(chrono::Utc::now().to_rfc3339()));
        }

        let metadata_str = clean_metadata.to_string();
        info!("IMMUTABLE LEDGER DISPATCH: type={}, group_id={}, metadata={}", event_type, group_id, metadata_str);

        // 2. Suppress database updates if environment configuration is empty (developer local testing)
        let supabase_url = std::env::var("SUPABASE_URL").unwrap_or_default();
        let supabase_key = std::env::var("SUPABASE_ANON_KEY").unwrap_or_default();

        if !supabase_url.is_empty() && !supabase_key.is_empty() {
            let client = reqwest::Client::new();
            let rpc_url = format!("{}/rest/v1/rpc/log_group_event", supabase_url);
            
            let result = client.post(&rpc_url)
                .header("apikey", &supabase_key)
                .header("Authorization", format!("Bearer {}", &supabase_key))
                .header("Content-Type", "application/json")
                .json(&json!({
                    "p_group_id": group_id,
                    "p_file_id": null,
                    "p_event_type": event_type,
                    "p_metadata": clean_metadata
                }))
                .send()
                .await;

            match result {
                Ok(resp) => {
                    if !resp.status().is_success() {
                        warn!("Supabase Ledger RPC returned failure: status={}", resp.status());
                    } else {
                        info!("Event successfully committed to Postgres Audit Ledger.");
                    }
                }
                Err(e) => {
                    warn!("Network error sending event to Postgres Audit Ledger: {}", e);
                }
            }
        }
    }
}
