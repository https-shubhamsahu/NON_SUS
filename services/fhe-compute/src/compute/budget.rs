use lazy_static::lazy_static;
use prometheus::{Counter, register_counter};
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};

lazy_static! {
    pub static ref BUDGET_EXCEEDED_COUNTER: Counter = register_counter!(
        "fhe_compute_budget_exceeded_total",
        "Total number of FHE compute jobs terminated due to budget exhaust"
    )
    .unwrap();
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ComputeBudget {
    pub max_additions: u32,
    pub max_multiplications: u32,
    pub max_comparisons: u32,
    pub max_mux: u32,
    pub max_circuit_depth: u32,
    pub max_runtime_millis: u64,
    pub max_memory_bytes: u64,
    pub max_ciphertext_size_bytes: usize,
}

impl Default for ComputeBudget {
    fn default() -> Self {
        Self {
            max_additions: 1000,
            max_multiplications: 100,
            max_comparisons: 50,
            max_mux: 50,
            max_circuit_depth: 10,
            max_runtime_millis: 10000,                   // 10 seconds
            max_memory_bytes: 50 * 1024 * 1024,          // 50MB
            max_ciphertext_size_bytes: 10 * 1024 * 1024, // 10MB
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum BudgetError {
    AdditionsExceeded,
    MultiplicationsExceeded,
    ComparisonsExceeded,
    MuxExceeded,
    DepthExceeded,
    RuntimeExceeded,
    MemoryExceeded,
    CiphertextSizeExceeded(usize),
}

pub struct BudgetTracker {
    pub budget: ComputeBudget,
    pub current_additions: u32,
    pub current_multiplications: u32,
    pub current_comparisons: u32,
    pub current_mux: u32,
    pub current_depth: u32,
    pub start_time: std::time::Instant,
}

impl BudgetTracker {
    pub fn new(budget: ComputeBudget) -> Self {
        Self {
            budget,
            current_additions: 0,
            current_multiplications: 0,
            current_comparisons: 0,
            current_mux: 0,
            current_depth: 0,
            start_time: std::time::Instant::now(),
        }
    }

    /// Verifies if runtime budget is still valid
    pub fn check_runtime(&self) -> Result<(), BudgetError> {
        let elapsed = self.start_time.elapsed().as_millis() as u64;
        if elapsed > self.budget.max_runtime_millis {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::RuntimeExceeded);
        }
        Ok(())
    }

    /// Increments and checks addition budget
    pub fn record_addition(&mut self) -> Result<(), BudgetError> {
        self.check_runtime()?;
        self.current_additions += 1;
        if self.current_additions > self.budget.max_additions {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::AdditionsExceeded);
        }
        Ok(())
    }

    /// Increments and checks multiplication budget
    pub fn record_multiplication(&mut self) -> Result<(), BudgetError> {
        self.check_runtime()?;
        self.current_multiplications += 1;
        if self.current_multiplications > self.budget.max_multiplications {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::MultiplicationsExceeded);
        }
        Ok(())
    }

    /// Increments and checks comparison budget
    pub fn record_comparison(&mut self) -> Result<(), BudgetError> {
        self.check_runtime()?;
        self.current_comparisons += 1;
        if self.current_comparisons > self.budget.max_comparisons {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::ComparisonsExceeded);
        }
        Ok(())
    }

    /// Increments and checks MUX selection budget
    pub fn record_mux(&mut self) -> Result<(), BudgetError> {
        self.check_runtime()?;
        self.current_mux += 1;
        if self.current_mux > self.budget.max_mux {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::MuxExceeded);
        }
        Ok(())
    }

    /// Tracks and checks circuit depth increments
    pub fn record_depth(&mut self, depth: u32) -> Result<(), BudgetError> {
        self.current_depth = self.current_depth.max(depth);
        if self.current_depth > self.budget.max_circuit_depth {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::DepthExceeded);
        }
        Ok(())
    }

    /// Checks if a ciphertext size is within bounds
    pub fn check_ciphertext_size(&self, size: usize) -> Result<(), BudgetError> {
        if size > self.budget.max_ciphertext_size_bytes {
            BUDGET_EXCEEDED_COUNTER.inc();
            return Err(BudgetError::CiphertextSizeExceeded(size));
        }
        Ok(())
    }
}
