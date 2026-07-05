use axum::{Json, response::IntoResponse};
use crate::models::HealthResponse;
use std::time::SystemTime;

lazy_static::lazy_static! {
    static ref START_TIME: SystemTime = SystemTime::now();
}

pub async fn health_handler() -> impl IntoResponse {
    let uptime = START_TIME.elapsed().map(|d| d.as_secs()).unwrap_or(0);

    // Simulated RAM metrics for health check (FHE environments are RAM-critical)
    let response = HealthResponse {
        status: "healthy".to_string(),
        uptime_seconds: uptime,
        ram_used_bytes: 1_200_000_000,
        ram_total_bytes: 8_589_934_592,
    };

    Json(response)
}
