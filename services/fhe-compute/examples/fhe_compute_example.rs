use fhe_compute::compute::{
    EncryptedUint32, ArithmeticEngine, ZamaArithmeticEngine,
    ZamaComparisonEngine, ComparisonEngine,
    ZamaMuxEngine, MuxEngine,
};
use tfhe::prelude::*;
use tfhe::{ConfigBuilder, ClientKey, ServerKey, FheUint32};

fn main() {
    println!("--- Running TFHE decoupled compute engine example ---");

    // 1. Setup TFHE parameters (client generates keys)
    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let server_key = ServerKey::new(&client_key);

    // Set server key context
    tfhe::set_server_key(server_key);

    // 2. Encrypt values on the client
    let val_a = 50u32;
    let val_b = 20u32;

    let ct_a = FheUint32::try_encrypt(val_a, &client_key).unwrap();
    let ct_b = FheUint32::try_encrypt(val_b, &client_key).unwrap();

    // 3. Serialize to abstract wrappers
    let wrap_a = EncryptedUint32 {
        raw_bytes: bincode::serialize(&ct_a).unwrap(),
    };
    let wrap_b = EncryptedUint32 {
        raw_bytes: bincode::serialize(&ct_b).unwrap(),
    };

    // 4. Perform computations using decoupled engine traits
    let arithmetic = ZamaArithmeticEngine;
    let sum_wrap = arithmetic.add(&wrap_a, &wrap_b).unwrap();

    let decrypted_sum: FheUint32 = bincode::deserialize(&sum_wrap.raw_bytes).unwrap();
    let val_sum: u32 = decrypted_sum.decrypt(&client_key);
    println!("Homomorphic Sum: {} + {} = {}", val_a, val_b, val_sum);
    assert_eq!(val_sum, val_a + val_b);

    // 5. Compare using comparison engine
    let comparison = ZamaComparisonEngine;
    let gt_wrap = comparison.gt(&wrap_a, &wrap_b).unwrap();

    // 6. Perform selection using Mux engine
    let mux = ZamaMuxEngine;
    // Select wrap_a if gt is true, else wrap_b
    let selected_wrap = mux.select(&gt_wrap, &wrap_a, &wrap_b).unwrap();

    let decrypted_selected: FheUint32 = bincode::deserialize(&selected_wrap.raw_bytes).unwrap();
    let val_selected: u32 = decrypted_selected.decrypt(&client_key);
    println!("Mux Selection (Select Greater): {}", val_selected);
    assert_eq!(val_selected, val_a);

    println!("Decoupled FHE computation validation PASSED.");
}
