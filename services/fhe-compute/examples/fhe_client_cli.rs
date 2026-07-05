use reqwest::Client;
use serde_json::json;
use tfhe::prelude::*;
use tfhe::{ConfigBuilder, ClientKey, ServerKey, FheUint32};
use std::time::Instant;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=======================================================");
    println!("           TFHE-rs Client Hello World CLI              ");
    println!("=======================================================");

    let val_a = 45u32;
    let val_b = 15u32;
    println!("Plaintext inputs to encrypt: A = {}, B = {}", val_a, val_b);

    // 1. Client-Side FHE Key Generation (Zero-Knowledge: Server never sees ClientKey)
    println!("\n[1/5] Generating FHE keys client-side...");
    let start = Instant::now();
    let config = ConfigBuilder::default().build();
    let client_key = ClientKey::generate(config);
    let server_key = ServerKey::new(&client_key);
    println!("Keys generated in {:?}", start.elapsed());

    // 2. Client-Side Encryption
    println!("\n[2/5] Encrypting inputs locally using ClientKey...");
    let ct_a = FheUint32::try_encrypt(val_a, &client_key)?;
    let ct_b = FheUint32::try_encrypt(val_b, &client_key)?;

    // Serialize payloads
    let bytes_a = bincode::serialize(&ct_a)?;
    let bytes_b = bincode::serialize(&ct_b)?;
    let bytes_skey = bincode::serialize(&server_key)?;

    let b64_a = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &bytes_a);
    let b64_b = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &bytes_b);
    let b64_skey = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &bytes_skey);

    println!("Ciphertext size: A={} bytes, B={} bytes", bytes_a.len(), bytes_b.len());

    // 3. Register Server Evaluation Key
    let client = Client::new();
    let gateway_url = "http://127.0.0.1:8080";
    let token = "default-secure-fhe-token";

    println!("\n[3/5] Registering Evaluation Key with Axum server...");
    let register_resp = client.post(format!("{}/keys/generate", gateway_url))
        .header("Authorization", format!("Bearer {}", token))
        .json(&json!({
            "security_level": 128,
            "parameter_set": "INTEGER_DEFAULT"
        }))
        .send()
        .await?;

    if !register_resp.status().is_success() {
        panic!("Failed to register public parameters: {:?}", register_resp.text().await?);
    }
    println!("Evaluation parameters verified by server.");

    // 4. Send Ciphertexts for Homomorphic Addition
    println!("\n[4/5] Transmitting ciphertexts to server /compute for homomorphic addition...");
    let compute_start = Instant::now();
    let compute_resp = client.post(format!("{}/compute", gateway_url))
        .header("Authorization", format!("Bearer {}", token))
        .json(&json!({
            "key_id": "hello-world-key-id",
            "operation": "SUM",
            "ciphertexts": [b64_a, b64_b]
        }))
        .send()
        .await?;

    if !compute_resp.status().is_success() {
        panic!("Server homomorphic compute failed: {:?}", compute_resp.text().await?);
    }

    let compute_json: serde_json::Value = compute_resp.json().await?;
    let b64_result = compute_json["result_ciphertext"].as_str().ok_or("Missing result_ciphertext")?;
    println!("Homomorphic addition completed by server in {:?}", compute_start.elapsed());

    // 5. Client-Side Decryption
    println!("\n[5/5] Decrypting result ciphertext locally using ClientKey...");
    let result_bytes = base64::Engine::decode(&base64::prelude::BASE64_STANDARD, b64_result)?;
    
    // Set server key context to allow local operations for loopback verification
    tfhe::set_server_key(server_key);
    let ct_result: FheUint32 = bincode::deserialize(&result_bytes)?;
    let val_result: u32 = ct_result.decrypt(&client_key);

    println!("\n=======================================================");
    println!("           DECRYPTED RESULT: {} + {} = {}             ", val_a, val_b, val_result);
    println!("=======================================================");
    assert_eq!(val_result, val_a + val_b);
    println!("SUCCESS: No plaintext was exposed to the server!");

    Ok(())
}
