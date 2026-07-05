use fhe_compute::crypto::{FheCryptosystem, MockEngine, TFHEEngine};

fn test_generic_engine<E: FheCryptosystem>(engine: E, name: &str) {
    println!("--- Testing Cryptosystem Abstraction: {} ---", name);

    // 1. Generate keys
    let (client_key, server_key) = engine.generate_keys();

    // 2. Encrypt plaintext inputs
    let val_a = 100u32;
    let val_b = 40u32;
    let ct_a = engine.encrypt(val_a, &client_key).unwrap();
    let ct_b = engine.encrypt(val_b, &client_key).unwrap();

    // 3. Perform homomorphic math in the server context
    let ct_sum = engine.add(&ct_a, &ct_b, &server_key).unwrap();
    let ct_mul = engine.multiply(&ct_a, &ct_b, &server_key).unwrap();

    // 4. Decrypt outcomes in the client context
    let sum = engine.decrypt(&ct_sum, &client_key).unwrap();
    let mul = engine.decrypt(&ct_mul, &client_key).unwrap();

    println!("Sum outcome: {}", sum);
    println!("Mul outcome: {}", mul);

    assert_eq!(sum, val_a + val_b);
    assert_eq!(mul, val_a * val_b);

    // 5. Compare & Mux
    let ct_gt = engine.gt(&ct_a, &ct_b, &server_key).unwrap();
    let ct_mux = engine.mux(&ct_gt, &ct_a, &ct_b, &server_key).unwrap();
    let selected = engine.decrypt(&ct_mux, &client_key).unwrap();

    println!("MUX selected value (greater): {}", selected);
    assert_eq!(selected, val_a);

    println!("Generic abstraction testing for {} PASSED.\n", name);
}

fn main() {
    // We can run the validation against the MockEngine instantly (saves CPU hours)
    let mock = MockEngine;
    test_generic_engine(mock, "MockEngine");

    // We can also run the exact same logic using TFHEEngine (Zama backend)
    let tfhe = TFHEEngine;
    test_generic_engine(tfhe, "TFHEEngine");
}
