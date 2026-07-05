use fhe_compute::keys::{TenantRegistryManager};
use std::time::Duration;

#[test]
fn test_tenant_context_isolation_verification() {
    TenantRegistryManager::reset();

    let tenant_a = "tenant-uuid-aaaa-1111";
    let tenant_b = "tenant-uuid-bbbb-2222";

    // 1. Resolve isolated contexts
    let ctx_a = TenantRegistryManager::get_context(tenant_a);
    let ctx_b = TenantRegistryManager::get_context(tenant_b);

    // Assert isolated instances
    assert_eq!(ctx_a.tenant_id, tenant_a);
    assert_eq!(ctx_b.tenant_id, tenant_b);

    // 2. Verify Key Cache isolation (Keys mapped to Tenant A must not resolve on Tenant B)
    let key_id = "test-key-id".to_string();
    let key_data = vec![5u8; 100];
    ctx_a.key_manager.cache_evaluation_key(key_id.clone(), key_data.clone(), Duration::from_secs(60));

    // Tenant A retrieves successfully
    assert!(ctx_a.key_manager.get_evaluation_key(&key_id).is_some());

    // Tenant B gets None (complete namespace isolation!)
    assert!(ctx_b.key_manager.get_evaluation_key(&key_id).is_none());
}

#[test]
fn test_tenant_metrics_isolation() {
    TenantRegistryManager::reset();

    let tenant_x = "tenant-x";
    let tenant_y = "tenant-y";

    let ctx_x = TenantRegistryManager::get_context(tenant_x);
    let ctx_y = TenantRegistryManager::get_context(tenant_y);

    // Increment Tenant X metrics
    ctx_x.metrics.inc_completed();
    ctx_x.metrics.inc_completed();

    assert_eq!(ctx_x.metrics.get_completed(), 2);
    assert_eq!(ctx_y.metrics.get_completed(), 0); // Tenant Y remains untouched
}
