use serde_json::json;
use tracing::{info, warn};

/// Mirrors async-job outcomes back to the Supabase `fhe_compute_jobs` row the
/// fhe-proxy created, so the Flutter client (subscribed via realtime/RLS) sees
/// completion without polling this service.
///
/// Writes go through PostgREST with the service-role key (bypasses RLS, as the
/// migration intends: "the worker performs all other status transitions").
/// When SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are not configured (local
/// dev), this is a silent no-op. Only the ciphertext RESULT and aggregate
/// status ever leave this process — never key material or plaintext.
pub struct JobSync;

impl JobSync {
    /// Maps the internal queue status to the DB check-constraint vocabulary
    /// ('pending','queued','running','completed','failed','cancelled','dead_letter').
    fn db_status(internal: &str) -> &str {
        match internal {
            "processing" => "running",
            other => other,
        }
    }

    pub async fn sync_job_result(
        remote_job_id: &str,
        status: &str,
        progress: f32,
        result_ciphertext: Option<&str>,
        error: Option<&str>,
    ) {
        let supabase_url = std::env::var("SUPABASE_URL").unwrap_or_default();
        let service_key = std::env::var("SUPABASE_SERVICE_ROLE_KEY").unwrap_or_default();
        if supabase_url.is_empty() || service_key.is_empty() {
            return; // local development: nothing to mirror to
        }

        let mut body = json!({
            "status": Self::db_status(status),
            "progress": progress,
        });
        if let Some(ct) = result_ciphertext {
            body["result_ciphertext"] = json!(ct);
        }
        if let Some(err) = error {
            body["error"] = json!(err);
        }

        let url = format!(
            "{}/rest/v1/fhe_compute_jobs?id=eq.{}",
            supabase_url, remote_job_id
        );
        let client = reqwest::Client::new();
        let res = client
            .patch(&url)
            .header("apikey", &service_key)
            .header("Authorization", format!("Bearer {}", &service_key))
            .header("Content-Type", "application/json")
            .header("Prefer", "return=minimal")
            .json(&body)
            .send()
            .await;

        match res {
            Ok(resp) if resp.status().is_success() => {
                info!("Job {} mirrored to fhe_compute_jobs (status={})", remote_job_id, status);
            }
            Ok(resp) => {
                warn!(
                    "Job {} mirror write rejected by PostgREST: status={}",
                    remote_job_id,
                    resp.status()
                );
            }
            Err(e) => {
                warn!("Job {} mirror write failed: {}", remote_job_id, e);
            }
        }
    }
}
