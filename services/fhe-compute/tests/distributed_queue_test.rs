use fhe_compute::services::aggregation::{DistributedQueue, JobStatus};
use fhe_compute::models::ComputeRequest;
use std::time::Duration;

#[test]
fn test_queue_capacity_limit_backpressure() {
    let queue = DistributedQueue::new();

    // Fill queue to capacity (simulating 1000 items)
    // Wait, let's inspect that we can trigger the Err case on capacity
    // To make it easy to test, the maximum capacity is 1000. Let's submit 1001 items.
    for i in 0..1000 {
        let payload = ComputeRequest {
            key_id: "test-key".to_string(),
            operation: "SUM".to_string(),
            ciphertexts: vec![],
            priority: Some(1),
            timeout_seconds: Some(5),
            tenant_id: None,
            job_id: None,
        };
        assert!(queue.submit_job(payload).is_ok());
    }

    // 1001st item must be rejected by backpressure limits
    let overflow_payload = ComputeRequest {
        key_id: "test-key".to_string(),
        operation: "SUM".to_string(),
        ciphertexts: vec![],
        priority: Some(1),
        timeout_seconds: Some(5),
        tenant_id: None,
        job_id: None,
    };
    let result = queue.submit_job(overflow_payload);
    assert_eq!(result, Err("Server busy: Max compute queue capacity reached (backpressure)."));
}

#[test]
fn test_stale_job_recovery_heartbeat() {
    let queue = DistributedQueue::new();
    let payload = ComputeRequest {
        key_id: "test-key".to_string(),
        operation: "SUM".to_string(),
        ciphertexts: vec![],
        priority: Some(1),
        timeout_seconds: Some(1), // 1s timeout
        tenant_id: None,
        job_id: None,
    };

    let job_id = queue.submit_job(payload).unwrap();

    // Simulate worker locking the job as processing
    // Wait, let's update status to processing with a start time in the past
    // The monitor checks start_time.elapsed() > job.timeout
    // Let's call the helper in aggregation.rs:
    // ...
}
