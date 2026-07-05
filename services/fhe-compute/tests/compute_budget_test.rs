use fhe_compute::compute::{ComputeBudget, BudgetTracker, BudgetError};

#[test]
fn test_addition_budget_limit_exhausted() {
    let budget = ComputeBudget {
        max_additions: 3,
        ..ComputeBudget::default()
    };
    let mut tracker = BudgetTracker::new(budget);

    assert!(tracker.record_addition().is_ok());
    assert!(tracker.record_addition().is_ok());
    assert!(tracker.record_addition().is_ok());

    // 4th addition must fail
    assert_eq!(tracker.record_addition(), Err(BudgetError::AdditionsExceeded));
}

#[test]
fn test_multiplication_budget_limit_exhausted() {
    let budget = ComputeBudget {
        max_multiplications: 2,
        ..ComputeBudget::default()
    };
    let mut tracker = BudgetTracker::new(budget);

    assert!(tracker.record_multiplication().is_ok());
    assert!(tracker.record_multiplication().is_ok());

    // 3rd multiplication must fail
    assert_eq!(tracker.record_multiplication(), Err(BudgetError::MultiplicationsExceeded));
}

#[test]
fn test_runtime_budget_limit_exhausted() {
    let budget = ComputeBudget {
        max_runtime_millis: 10,
        ..ComputeBudget::default()
    };
    let mut tracker = BudgetTracker::new(budget);

    // Sleep to exceed 10ms max runtime
    std::thread::sleep(std::time::Duration::from_millis(15));

    // Next operation must report runtime exceeded
    assert_eq!(tracker.record_addition(), Err(BudgetError::RuntimeExceeded));
}

#[test]
fn test_ciphertext_size_check() {
    let budget = ComputeBudget {
        max_ciphertext_size_bytes: 1024,
        ..ComputeBudget::default()
    };
    let tracker = BudgetTracker::new(budget);

    assert!(tracker.check_ciphertext_size(500).is_ok());
    assert_eq!(
        tracker.check_ciphertext_size(1025),
        Err(BudgetError::CiphertextSizeExceeded(1025))
    );
}
