use crate::compute;
use crate::models::{ComputeRequest, JobStatusResponse};
use lazy_static::lazy_static;
use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime};
use tracing::{error, info, warn};
use uuid::Uuid;

// Maximum capacity limit to enforce backpressure
const MAX_QUEUE_CAPACITY: usize = 1000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JobStatus {
    Pending,
    Processing,
    Completed,
    Failed,
    Cancelled,
    DeadLetter,
}

impl JobStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            JobStatus::Pending => "pending",
            JobStatus::Processing => "processing",
            JobStatus::Completed => "completed",
            JobStatus::Failed => "failed",
            JobStatus::Cancelled => "cancelled",
            JobStatus::DeadLetter => "dead_letter",
        }
    }
}

#[derive(Debug, Clone)]
pub struct Job {
    pub id: String,
    pub priority: u8,
    pub status: JobStatus,
    pub payload: ComputeRequest,
    pub retry_count: u8,
    pub max_retries: u8,
    pub progress: f32,
    pub result: Option<String>,
    pub timeout: Duration,
    pub error: Option<String>,
    pub created_at: SystemTime,
    pub scheduled_at: Option<Instant>,
}

// Implement Ord to prioritize higher priority values, then older creation times (FIFO)
impl Eq for Job {}

impl PartialEq for Job {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id
    }
}

impl Ord for Job {
    fn cmp(&self, other: &Self) -> Ordering {
        // Compare priority first (highest first)
        let priority_ord = self.priority.cmp(&other.priority);
        if priority_ord != Ordering::Equal {
            return priority_ord;
        }
        // If priorities are equal, compare creation times (older first -> FIFO)
        other.created_at.cmp(&self.created_at)
    }
}

impl PartialOrd for Job {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub struct DistributedQueue {
    queue: Mutex<BinaryHeap<Job>>,
    jobs: Mutex<HashMap<String, Job>>,
    dlq: Mutex<HashMap<String, Job>>,
}

lazy_static! {
    pub static ref DISTRIBUTED_QUEUE: Arc<DistributedQueue> = {
        let manager = Arc::new(DistributedQueue::new());
        // Start background worker pool and monitoring sweeps
        manager.clone().start_worker_pool(4);
        manager.clone().start_heartbeat_monitor();
        manager
    };
}

impl DistributedQueue {
    pub fn new() -> Self {
        Self {
            queue: Mutex::new(BinaryHeap::new()),
            jobs: Mutex::new(HashMap::new()),
            dlq: Mutex::new(HashMap::new()),
        }
    }

    /// Submits a job. Enforces backpressure if capacity limits are exceeded.
    pub fn submit_job(&self, payload: ComputeRequest) -> Result<String, &'static str> {
        let mut queue = self.queue.lock().unwrap();

        // Enforce backpressure capacity ceiling
        if queue.len() >= MAX_QUEUE_CAPACITY {
            warn!("Queue capacity ceiling breached. Rejecting new FHE submissions.");
            return Err("Server busy: Max compute queue capacity reached (backpressure).");
        }

        let job_id = Uuid::new_v4().to_string();
        let priority = payload.priority.unwrap_or(1);
        let timeout = Duration::from_secs(payload.timeout_seconds.unwrap_or(30));

        let job = Job {
            id: job_id.clone(),
            priority,
            status: JobStatus::Pending,
            payload,
            retry_count: 0,
            max_retries: 3,
            progress: 0.0,
            result: None,
            timeout,
            error: None,
            created_at: SystemTime::now(),
            scheduled_at: None,
        };

        // Track in registry
        {
            let mut jobs = self.jobs.lock().unwrap();
            jobs.insert(job_id.clone(), job.clone());
        }

        queue.push(job);
        info!(
            "Job {} registered in priority queue. Priority={}",
            job_id, priority
        );
        Ok(job_id)
    }

    pub fn get_job_status(&self, job_id: &str) -> Option<JobStatusResponse> {
        let jobs = self.jobs.lock().unwrap();
        jobs.get(job_id).map(|j| JobStatusResponse {
            job_id: j.id.clone(),
            status: j.status.as_str().to_string(),
            progress: j.progress,
            result: j.result.clone(),
        })
    }

    pub fn cancel_job(&self, job_id: &str) -> bool {
        let mut jobs = self.jobs.lock().unwrap();
        if let Some(job) = jobs.get_mut(job_id) {
            if job.status == JobStatus::Pending || job.status == JobStatus::Processing {
                job.status = JobStatus::Cancelled;
                info!("Job {} marked as Cancelled", job_id);
                return true;
            }
        }
        false
    }

    fn update_job_status(
        &self,
        job_id: &str,
        status: JobStatus,
        progress: f32,
        result: Option<String>,
        err: Option<String>,
    ) {
        let mut jobs = self.jobs.lock().unwrap();
        if let Some(job) = jobs.get_mut(job_id) {
            if job.status != JobStatus::Cancelled {
                job.status = status;
                job.progress = progress;
                job.result = result;
                job.error = err;
            }
        }
    }

    fn start_worker_pool(self: Arc<Self>, num_workers: usize) {
        for worker_id in 0..num_workers {
            let manager = Arc::clone(&self);
            tokio::spawn(async move {
                manager.worker_loop(worker_id).await;
            });
        }
    }

    async fn worker_loop(&self, worker_id: usize) {
        info!("Distributed Queue Worker {} started.", worker_id);
        loop {
            let job = {
                let mut queue = self.queue.lock().unwrap();
                queue.pop()
            };

            if let Some(mut job) = job {
                // Check cancellation
                {
                    let jobs = self.jobs.lock().unwrap();
                    if let Some(stored) = jobs.get(&job.id) {
                        if stored.status == JobStatus::Cancelled {
                            continue;
                        }
                    }
                }

                job.scheduled_at = Some(Instant::now());
                self.update_job_status(&job.id, JobStatus::Processing, 0.1, None, None);

                // Run FHE calculation under worker timeout constraints
                let execution = tokio::time::timeout(job.timeout, self.execute_job(&job));
                match execution.await {
                    Ok(Ok(computed_result)) => {
                        info!("Worker {} completed Job {}", worker_id, job.id);
                        // Mirror the result to the Supabase fhe_compute_jobs row the
                        // proxy created (no-op when unconfigured / job has no mirror).
                        if let Some(remote_id) = job.payload.job_id.as_deref() {
                            crate::services::job_sync::JobSync::sync_job_result(
                                remote_id,
                                "completed",
                                1.0,
                                Some(&computed_result),
                                None,
                            )
                            .await;
                        }
                        self.update_job_status(
                            &job.id,
                            JobStatus::Completed,
                            1.0,
                            Some(computed_result),
                            None,
                        );
                    }
                    Ok(Err(err)) => {
                        warn!("Worker {} failed Job {}: {}", worker_id, job.id, err);
                        self.handle_failure(job, err).await;
                    }
                    Err(_) => {
                        error!("Worker {} Job {} timed out", worker_id, job.id);
                        self.handle_failure(job, "Execution timeout exceeded".to_string())
                            .await;
                    }
                }
            } else {
                tokio::time::sleep(Duration::from_millis(100)).await;
            }
        }
    }

    async fn execute_job(&self, job: &Job) -> Result<String, String> {
        // Load the owning tenant's evaluation key onto this worker thread so
        // the homomorphic operations run under the matching parameter set
        // (mirrors compute_handler). Falls back to the shared local-dev tenant
        // for direct-mode jobs submitted without the fhe-proxy.
        let tenant = job
            .payload
            .tenant_id
            .as_deref()
            .unwrap_or("local-dev-tenant");
        let keys = crate::crypto::TENANT_KEY_STORE.get_or_create(tenant);
        tfhe::set_server_key(keys.server_key.clone());

        // Run decoupled abstract operation
        let result = match job.payload.operation.to_uppercase().as_str() {
            "PRODUCT" => compute::homomorphic_product(&job.payload.ciphertexts),
            "SIMILARITY" | "DOT_PRODUCT" => {
                compute::homomorphic_inner_product_split(&job.payload.ciphertexts)?
            }
            _ => compute::homomorphic_sum(&job.payload.ciphertexts),
        };
        Ok(result)
    }

    /// Handles failures using Exponential Backoff with jitter retry policies
    async fn handle_failure(&self, mut job: Job, err: String) {
        if job.retry_count < job.max_retries {
            job.retry_count += 1;
            job.status = JobStatus::Pending;
            job.progress = 0.0;
            job.error = Some(err.clone());

            // Calculate exponential backoff sleep: (2^retry) seconds + random jitter
            let backoff_secs = (2u64.pow(job.retry_count as u32)) + (rand_jitter() % 3);
            warn!(
                "Scheduling retry {}/{} for Job {} in {} seconds",
                job.retry_count, job.max_retries, job.id, backoff_secs
            );

            let queue_clone = self.queue.lock().unwrap();
            let jobs_clone = self.jobs.lock().unwrap();
            // We simulate asynchronous delay before re-pushing into priority queue
            let id = job.id.clone();
            let manager_queue = DISTRIBUTED_QUEUE.clone();
            tokio::spawn(async move {
                tokio::time::sleep(Duration::from_secs(backoff_secs)).await;
                let mut q = manager_queue.queue.lock().unwrap();
                let mut js = manager_queue.jobs.lock().unwrap();
                q.push(job.clone());
                js.insert(id, job);
            });
        } else {
            // Push permanently failed jobs to Dead-Letter Queue (DLQ)
            job.status = JobStatus::DeadLetter;
            job.progress = 1.0;
            job.error = Some(format!("Max retries reached. Permanent Failure: {}", err));

            // Mirror the terminal failure to the Supabase row (no-op locally).
            if let Some(remote_id) = job.payload.job_id.as_deref() {
                crate::services::job_sync::JobSync::sync_job_result(
                    remote_id,
                    "dead_letter",
                    1.0,
                    None,
                    job.error.as_deref(),
                )
                .await;
            }

            {
                let mut dlq = self.dlq.lock().unwrap();
                dlq.insert(job.id.clone(), job.clone());
            }
            {
                let mut jobs = self.jobs.lock().unwrap();
                jobs.insert(job.id.clone(), job.clone());
            }
            error!(
                "Job {} permanently failed. Sent to Dead-Letter Queue (DLQ).",
                job.id
            );
        }
    }

    /// Monitors processing heartbeats to recover aborted nodes/jobs
    fn start_heartbeat_monitor(self: Arc<Self>) {
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(10)).await;
                self.sweep_stale_processing_jobs();
            }
        });
    }

    fn sweep_stale_processing_jobs(&self) {
        let mut jobs = self.jobs.lock().unwrap();
        let mut queue = self.queue.lock().unwrap();

        for (id, job) in jobs.iter_mut() {
            if job.status == JobStatus::Processing {
                if let Some(start_time) = job.scheduled_at {
                    if start_time.elapsed() > job.timeout + Duration::from_secs(5) {
                        warn!(
                            "Detected stale/crashed worker processing Job {}. Resetting to pending.",
                            id
                        );
                        job.status = JobStatus::Pending;
                        job.scheduled_at = None;
                        queue.push(job.clone());
                    }
                }
            }
        }
    }
}

fn rand_jitter() -> u64 {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH_MOCK)
        .unwrap()
        .as_nanos();
    (now % 5) as u64
}

const UNIX_EPOCH_MOCK: SystemTime = SystemTime::UNIX_EPOCH;

// Wrapper APIs matching existing stub endpoints signature
pub fn create_job() -> String {
    let payload = ComputeRequest {
        key_id: "default".to_string(),
        operation: "SUM".to_string(),
        ciphertexts: vec![],
        priority: Some(1),
        timeout_seconds: Some(30),
        tenant_id: None,
        job_id: None,
    };
    DISTRIBUTED_QUEUE.submit_job(payload).unwrap_or_default()
}

pub fn update_job(job_id: &str, status: &str, progress: f32, result: Option<String>) {
    let job_status = match status {
        "processing" => JobStatus::Processing,
        "completed" => JobStatus::Completed,
        "failed" => JobStatus::Failed,
        "cancelled" => JobStatus::Cancelled,
        _ => JobStatus::Pending,
    };
    DISTRIBUTED_QUEUE.update_job_status(job_id, job_status, progress, result, None);
}

pub fn get_job(job_id: &str) -> Option<JobStatusResponse> {
    DISTRIBUTED_QUEUE.get_job_status(job_id)
}
