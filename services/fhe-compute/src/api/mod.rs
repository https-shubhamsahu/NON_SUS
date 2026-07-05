use axum::{
    routing::{get, post},
    Router,
    middleware,
};
use tower_http::cors::CorsLayer;

pub mod health;
pub mod metrics;
pub mod compute_handler;

pub fn build_router(settings: crate::config::Settings) -> Router {
    // 1. Public Routes
    let public_routes = Router::new()
        .route("/health", get(health::health_handler))
        .route("/metrics", get(metrics::metrics_handler));

    // 2. Private Cryptographic Computation Routes (Auth Protected)
    let private_routes = Router::new()
        .route("/keys/generate", post(compute_handler::generate_keys_handler))
        .route("/keys/rotate", post(compute_handler::rotate_keys_handler))
        .route("/keys/revoke", post(compute_handler::revoke_keys_handler))
        .route("/compute", post(compute_handler::compute_handler))
        .route("/encrypt", post(compute_handler::encrypt_handler))
        .route("/decrypt", post(compute_handler::decrypt_handler))
        .route("/compare", post(compute_handler::compare_handler))
        .route("/mux", post(compute_handler::mux_handler))
        .route("/similarity", post(compute_handler::similarity_handler))
        .route("/pact/evaluate", post(compute_handler::pact_evaluate_handler))
        .route("/memory/search", post(compute_handler::memory_search_handler))
        .route("/policy/evaluate", post(compute_handler::policy_evaluate_handler))
        .route("/jobs/:id", get(compute_handler::get_job_handler))
        .route("/job/:id", get(compute_handler::get_job_handler))
        .route("/jobs", post(compute_handler::submit_job_handler))
        .route("/jobs/:id/cancel", post(compute_handler::cancel_job_handler))
        .route_layer(middleware::from_fn_with_state(
            settings.clone(),
            crate::middleware::validate_token
        ))
        .route_layer(middleware::from_fn(
            crate::middleware::enforce_replay_protection
        ));

    // 3. Combine Router & Configure CORS
    Router::new()
        .merge(public_routes)
        .merge(private_routes)
        .layer(CorsLayer::permissive())
}
