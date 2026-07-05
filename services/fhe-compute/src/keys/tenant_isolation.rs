use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use lazy_static::lazy_static;
use crate::keys::lifecycle::KeyLifecycleManager;
use crate::services::aggregation::DistributedQueue;

/// Isolated metrics container for a single tenant.
pub struct TenantMetrics {
    pub tenant_id: String,
    pub compute_jobs_completed: Mutex<u64>,
}

impl TenantMetrics {
    pub fn new(tenant_id: String) -> Self {
        Self {
            tenant_id,
            compute_jobs_completed: Mutex::new(0),
        }
    }

    pub fn inc_completed(&self) {
        let mut count = self.compute_jobs_completed.lock().unwrap();
        *count += 1;
    }

    pub fn get_completed(&self) -> u64 {
        *self.compute_jobs_completed.lock().unwrap()
    }
}

/// Fully isolated context for a single tenant.
/// Holds private namespaces for keys, queues, caches, and telemetry.
pub struct TenantContext {
    pub tenant_id: String,
    pub key_manager: Arc<KeyLifecycleManager>,
    pub queue: Arc<DistributedQueue>,
    pub metrics: Arc<TenantMetrics>,
}

impl TenantContext {
    pub fn new(tenant_id: &str) -> Self {
        Self {
            tenant_id: tenant_id.to_string(),
            key_manager: Arc::new(KeyLifecycleManager::new()),
            queue: Arc::new(DistributedQueue::new()),
            metrics: Arc::new(TenantMetrics::new(tenant_id.to_string())),
        }
    }
}

// Thread-safe multi-tenant container map
lazy_static! {
    static ref TENANT_REGISTRY: Mutex<HashMap<String, Arc<TenantContext>>> = Mutex::new(HashMap::new());
}

pub struct TenantRegistryManager;

impl TenantRegistryManager {
    /// Retrieves or initializes an isolated context for a tenant.
    pub fn get_context(tenant_id: &str) -> Arc<TenantContext> {
        let mut registry = TENANT_REGISTRY.lock().unwrap();
        registry
            .entry(tenant_id.to_string())
            .or_insert_with(|| Arc::new(TenantContext::new(tenant_id)))
            .clone()
    }

    /// Resets the registry (mainly for testing cleanup)
    pub fn reset() {
        let mut registry = TENANT_REGISTRY.lock().unwrap();
        registry.clear();
    }
}
