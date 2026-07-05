use axum::response::IntoResponse;
use prometheus::{Encoder, TextEncoder, register_counter, register_histogram, register_gauge, Counter, Histogram, Gauge};
use lazy_static::lazy_static;

lazy_static! {
    pub static ref COMPUTE_REQUESTS: Counter = register_counter!(
        "fhe_compute_requests_total",
        "Total number of FHE compute requests received"
    ).unwrap();

    pub static ref BOOTSTRAP_DURATION: Histogram = register_histogram!(
        "fhe_bootstrap_duration_seconds",
        "Duration of homomorphic bootstrapping loops"
    ).unwrap();

    pub static ref COMPUTE_LATENCY: Histogram = register_histogram!(
        "fhe_compute_latency_seconds",
        "Latency of homomorphic compute operations"
    ).unwrap();

    pub static ref KEY_GEN_LATENCY: Histogram = register_histogram!(
        "fhe_key_gen_latency_seconds",
        "Latency of FHE key generation operations"
    ).unwrap();

    pub static ref QUEUE_LENGTH: Gauge = register_gauge!(
        "fhe_queue_length",
        "Current number of jobs in the priority queue"
    ).unwrap();

    pub static ref WORKER_COUNT: Gauge = register_gauge!(
        "fhe_worker_count",
        "Number of active FHE compute workers"
    ).unwrap();

    pub static ref MEMORY_USAGE: Gauge = register_gauge!(
        "fhe_memory_usage_bytes",
        "Current memory consumption of the compute node"
    ).unwrap();

    pub static ref CPU_USAGE: Gauge = register_gauge!(
        "fhe_cpu_usage_percent",
        "Current CPU consumption of the compute node"
    ).unwrap();

    pub static ref COMPUTE_FAILURES: Counter = register_counter!(
        "fhe_compute_failures_total",
        "Total number of failed homomorphic operations"
    ).unwrap();

    pub static ref COMPUTE_SUCCESSES: Counter = register_counter!(
        "fhe_compute_successes_total",
        "Total number of successful homomorphic operations"
    ).unwrap();
}

pub async fn metrics_handler() -> impl IntoResponse {
    // Dynamically update gauge values before gathering
    // Update worker count (hardcoded pool size is 4)
    WORKER_COUNT.set(4.0);

    // Update memory usage (mock values representing base overhead + active heap)
    MEMORY_USAGE.set(128.0 * 1024.0 * 1024.0); // 128MB baseline
    CPU_USAGE.set(12.5); // 12.5% idle usage baseline

    let encoder = TextEncoder::new();
    let metric_families = prometheus::gather();
    let mut buffer = vec![];
    encoder.encode(&metric_families, &mut buffer).unwrap();

    axum::response::Response::builder()
        .header("Content-Type", encoder.format_type())
        .body(axum::body::Body::from(buffer))
        .unwrap()
}
