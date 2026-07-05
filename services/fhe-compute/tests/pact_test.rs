// Proves the PACTS "conditional revelation" primitive end-to-end at the crypto
// layer: two parties seal their choices, the evaluator computes mutual-match
// entirely over ciphertext (never seeing either choice), and only the boolean
// outcome is decryptable by the pact-key holder.

use base64::Engine as _;
use fhe_compute::compute;
use fhe_compute::crypto::{FheCryptosystem, TFHEEngine, TENANT_KEY_STORE};
use tfhe::prelude::*;

/// Seals a party's choice (an arena id) under the shared pact key.
fn seal_choice(engine: &TFHEEngine, key: &tfhe::ClientKey, choice: u32) -> String {
    let ct = engine.encrypt(choice, key).expect("encrypt choice");
    let bytes = engine.serialize_uint32(&ct).expect("serialize choice");
    base64::prelude::BASE64_STANDARD.encode(bytes)
}

/// Decrypts the evaluator's encrypted-boolean result with the pact key.
fn open_result(b64: &str, key: &tfhe::ClientKey) -> bool {
    let bytes = base64::prelude::BASE64_STANDARD.decode(b64).expect("decode result");
    let ct_bool: tfhe::FheBool = bincode::deserialize(&bytes).expect("deserialize FheBool");
    ct_bool.decrypt(key)
}

#[test]
fn test_pact_resolves_when_mutual() {
    let engine = TFHEEngine;
    let pact = TENANT_KEY_STORE.get_or_create("pact-arena-mutual");
    tfhe::set_server_key(pact.server_key.clone());

    // Public arena ids.
    let (alice, bob) = (101u32, 202u32);

    // Alice picks Bob; Bob picks Alice → they matched.
    let alice_choice = seal_choice(&engine, &pact.client_key, bob);
    let bob_choice = seal_choice(&engine, &pact.client_key, alice);

    let sealed_result =
        compute::homomorphic_mutual_match(&alice_choice, alice, &bob_choice, bob).unwrap();

    assert!(
        open_result(&sealed_result, &pact.client_key),
        "a mutual pick must resolve the pact"
    );
}

#[test]
fn test_pact_stays_sealed_when_unrequited() {
    let engine = TFHEEngine;
    let pact = TENANT_KEY_STORE.get_or_create("pact-arena-unrequited");
    tfhe::set_server_key(pact.server_key.clone());

    let (alice, bob, carol) = (101u32, 202u32, 303u32);

    // Alice picks Bob, but Bob picks Carol → no match; Alice never learns Bob's pick.
    let alice_choice = seal_choice(&engine, &pact.client_key, bob);
    let bob_choice = seal_choice(&engine, &pact.client_key, carol);

    let sealed_result =
        compute::homomorphic_mutual_match(&alice_choice, alice, &bob_choice, bob).unwrap();

    assert!(
        !open_result(&sealed_result, &pact.client_key),
        "an unrequited pick must NOT resolve the pact"
    );
}

#[test]
fn test_pact_decrypt_roundtrip_via_library_api() {
    // Exercises the exact path the /pact/seal -> /pact/evaluate -> /pact/decrypt
    // service pipeline uses: compute::decrypt_mutual_match must open the
    // evaluator's verdict identically to a manual FheBool decrypt.
    let engine = TFHEEngine;
    let pact = TENANT_KEY_STORE.get_or_create("pact-arena-decrypt-api");
    tfhe::set_server_key(pact.server_key.clone());

    let (alice, bob) = (7u32, 9u32);
    let alice_choice = seal_choice(&engine, &pact.client_key, bob);
    let bob_choice = seal_choice(&engine, &pact.client_key, alice);

    let sealed_result =
        compute::homomorphic_mutual_match(&alice_choice, alice, &bob_choice, bob).unwrap();

    let mutual = compute::decrypt_mutual_match(&sealed_result, &pact.client_key)
        .expect("decrypt_mutual_match must open a valid verdict");
    assert!(mutual, "library decrypt must agree with a mutual pick");

    // Garbage input must error, not panic.
    assert!(compute::decrypt_mutual_match("not-base64!!!", &pact.client_key).is_err());
}

#[test]
fn test_pact_requires_both_directions() {
    // One-directional even when the id space overlaps: Alice picks Bob, Bob picks
    // Alice's id-minus-one. Guards against an evaluator that checks only one side.
    let engine = TFHEEngine;
    let pact = TENANT_KEY_STORE.get_or_create("pact-arena-onesided");
    tfhe::set_server_key(pact.server_key.clone());

    let (alice, bob) = (101u32, 202u32);
    let alice_choice = seal_choice(&engine, &pact.client_key, bob); // correct
    let bob_choice = seal_choice(&engine, &pact.client_key, alice - 1); // wrong

    let sealed_result =
        compute::homomorphic_mutual_match(&alice_choice, alice, &bob_choice, bob).unwrap();

    assert!(
        !open_result(&sealed_result, &pact.client_key),
        "a one-sided pick must not resolve the pact"
    );
}
