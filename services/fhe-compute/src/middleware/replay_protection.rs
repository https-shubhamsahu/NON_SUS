use axum::{
    body::Body,
    http::{Request, StatusCode},
    middleware::Next,
    response::Response,
    Json,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{SystemTime, UNIX_EPOCH};
use lazy_static::lazy_static;
use tracing::{warn, info};

// Validity window: 300 seconds (5 minutes)
const VALIDITY_WINDOW_SECS: u64 = 300;

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct ReplayHeaders {
    pub request_id: String,
    pub nonce: String,
    pub timestamp: u64,
    pub signature: String,
}

pub struct ReplayCache {
    // Nonces mapped to their creation timestamp
    nonces: Mutex<HashMap<String, u64>>,
}

impl ReplayCache {
    pub fn new() -> Self {
        Self {
            nonces: Mutex::new(HashMap::new()),
        }
    }

    /// Verifies if a nonce is unique and within validity limits. Inserts it if valid.
    pub fn verify_and_insert(&self, nonce: &str, timestamp: u64) -> Result<(), &'static str> {
        let current_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // 1. Clock drift check
        let drift = (current_time as i64 - timestamp as i64).abs();
        if drift > VALIDITY_WINDOW_SECS as i64 {
            return Err("Clock drift limit exceeded. Request expired.");
        }

        let mut nonces = self.nonces.lock().unwrap();

        // 2. Duplicate detection check
        if nonces.contains_key(nonce) {
            return Err("Duplicate request nonce detected. Replay blocked.");
        }

        // 3. Insert and record
        nonces.insert(nonce.to_string(), timestamp);
        Ok(())
    }

    /// Prunes expired nonces from memory
    pub fn prune(&self) {
        let current_time = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let mut nonces = self.nonces.lock().unwrap();
        nonces.retain(|_, &mut ts| {
            let age = current_time.saturating_sub(ts);
            age < VALIDITY_WINDOW_SECS
        });
        info!("Replay protection cache pruned successfully.");
    }
}

lazy_static! {
    pub static ref REPLAY_CACHE: Arc<ReplayCache> = {
        let cache = Arc::new(ReplayCache::new());
        // Spawn background task to prune expired nonces every 60s
        let cache_clone = cache.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(std::time::Duration::from_secs(60)).await;
                cache_clone.prune();
            }
        });
        cache
    };
}

/// Axum middleware to intercept incoming requests and enforce replay protection
pub async fn enforce_replay_protection(
    req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    // 1. Extract headers
    let request_id = req.headers().get("x-request-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    
    let nonce = req.headers().get("x-nonce")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    let timestamp = req.headers().get("x-timestamp")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.parse::<u64>().ok());

    let signature = req.headers().get("x-signature")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    if let (Some(rid), Some(nc), Some(ts), Some(sig)) = (request_id, nonce, timestamp, signature) {
        // 2. Validate cryptographic signature (Mock validation for demonstration, checks structural integrity)
        if !verify_signature_payload(&rid, &nc, ts, &sig) {
            warn!("Rejected request {}: invalid signature payload", rid);
            return Err(StatusCode::UNAUTHORIZED);
        }

        // 3. Check replay cache boundaries
        match REPLAY_CACHE.verify_and_insert(&nc, ts) {
            Ok(_) => {
                // Access granted, proceed to inner handlers
                Ok(next.run(req).await)
            }
            Err(err) => {
                warn!("Blocked replay attempt: {}", err);
                Err(StatusCode::CONFLICT)
            }
        }
    } else {
        warn!("Missing required replay protection headers");
        Err(StatusCode::BAD_REQUEST)
    }
}

fn verify_signature_payload(request_id: &str, nonce: &str, timestamp: u64, signature: &str) -> bool {
    // Structural verification check: Signature must contain valid hex bytes
    !signature.is_empty() && signature.chars().all(|c| c.is_ascii_hexdigit())
}
