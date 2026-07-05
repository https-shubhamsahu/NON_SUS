use tfhe::prelude::*;
use tfhe::{ConfigBuilder, ClientKey, ServerKey, CompactPublicKey, FheUint32};

#[test]
fn test_tfhe_lifecycle_and_arithmetic() {
    // 1. ClientKey & ServerKey Generation
    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let server_key = ServerKey::new(&client_key);

    // Set server key for current thread execution context
    tfhe::set_server_key(server_key);

    // 2. CompactPublicKey Generation
    let _public_key = CompactPublicKey::new(&client_key);

    // 3. Encryption & Decryption
    let val_a = 45u32;
    let val_b = 15u32;

    let ct_a = FheUint32::try_encrypt(val_a, &client_key).unwrap();
    let ct_b = FheUint32::try_encrypt(val_b, &client_key).unwrap();

    let decrypted_a: u32 = ct_a.decrypt(&client_key);
    let decrypted_b: u32 = ct_b.decrypt(&client_key);

    assert_eq!(decrypted_a, val_a, "Decrypted A does not match plaintext");
    assert_eq!(decrypted_b, val_b, "Decrypted B does not match plaintext");

    // 4. Homomorphic Addition
    let ct_add = &ct_a + &ct_b;
    let dec_add: u32 = ct_add.decrypt(&client_key);
    assert_eq!(dec_add, val_a + val_b, "Homomorphic addition failed");

    // 5. Homomorphic Multiplication
    let ct_mul = &ct_a * &ct_b;
    let dec_mul: u32 = ct_mul.decrypt(&client_key);
    assert_eq!(dec_mul, val_a * val_b, "Homomorphic multiplication failed");

    // 6. Equality Comparison
    let ct_eq = ct_a.eq(&ct_b);
    let dec_eq: bool = ct_eq.decrypt(&client_key);
    assert_eq!(dec_eq, val_a == val_b, "Homomorphic equality comparison failed");

    // 7. Greater-Than Comparison
    let ct_gt = ct_a.gt(&ct_b);
    let dec_gt: bool = ct_gt.decrypt(&client_key);
    assert_eq!(dec_gt, val_a > val_b, "Homomorphic greater-than comparison failed");

    // 8. Less-Than Comparison
    let ct_lt = ct_a.lt(&ct_b);
    let dec_lt: bool = ct_lt.decrypt(&client_key);
    assert_eq!(dec_lt, val_a < val_b, "Homomorphic less-than comparison failed");

    // 9. Conditional MUX
    // Select ct_a if ct_gt is true, else ct_b
    let ct_mux = ct_gt.if_then_else(&ct_a, &ct_b);
    let dec_mux: u32 = ct_mux.decrypt(&client_key);
    assert_eq!(dec_mux, if val_a > val_b { val_a } else { val_b }, "Homomorphic MUX failed");
}

#[test]
fn test_tfhe_serialization_deserialization() {
    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);

    let val = 42u32;
    let ct = FheUint32::try_encrypt(val, &client_key).unwrap();

    // Serialize ciphertext to bytes
    let serialized = bincode::serialize(&ct).unwrap();

    // Deserialize ciphertext from bytes
    let deserialized: FheUint32 = bincode::deserialize(&serialized).unwrap();

    let decrypted: u32 = deserialized.decrypt(&client_key);
    assert_eq!(decrypted, val, "Serialization/Deserialization failed");
}
