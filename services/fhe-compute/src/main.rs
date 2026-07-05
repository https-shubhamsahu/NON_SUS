use std::net::SocketAddr;
use tracing::info;

mod api;
mod compute;
mod config;
mod crypto;
mod keys;
mod middleware;
mod models;
mod services;

#[tokio::main]
async fn main() {
    // 1. Initialize logging
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .json()
        .init();

    info!("Starting TFHE-rs Compute microservice...");

    // 2. Load Configuration
    let settings = config::Settings::new().unwrap_or_else(|err| {
        panic!("Failed to load configuration: {}", err);
    });

    // 3. Build API Router
    let app = api::build_router(settings.clone());

    // 4. Bind and Listen
    let addr = SocketAddr::from(([0, 0, 0, 0], settings.server.port));
    info!("TFHE-rs Compute microservice listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
