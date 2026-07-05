use tfhe::prelude::*;
use tfhe::{FheBool, FheUint32};

// ─── Conditional Revelation: the pact evaluator ──────────────────────────────
//
// This is the load-bearing primitive behind PACTS. Two parties each SEAL their
// choice (the arena id of the person/option they picked) under the SAME pact
// key; the arena ids themselves are public. The evaluator decides, entirely over
// ciphertext, whether the two picked each other:
//
//     mutual = (a_choice == b_id) AND (b_choice == a_id)
//
// The evaluator never sees either plaintext choice, and even the boolean outcome
// stays encrypted until a pact-key holder decrypts it. A trusted server cannot
// do this (it would see the choices); commit-reveal lets the second mover learn
// then refuse; plain key-wrapping cannot compute a predicate that spans two
// parties' secrets. FHE is genuinely required.
//
// The op count is deliberately tiny (two scalar equalities + one boolean AND),
// which is the only FHE regime that is practical on free-tier hardware and fits
// the existing asynchronous job queue.
//
// NOTE (trust model, honest): in this pairwise MVP both choices are sealed under
// one shared pact key. Establishing that shared key without a trusted party
// (two-party seeded keygen / threshold DKG) is deferred — see the "v9" milestone
// in the product plan. This module proves the *evaluation* half of the protocol.

/// Homomorphic mutual-match predicate over two sealed choices (base64 TFHE
/// ciphertexts under the same pact key) and two public arena ids. Returns the
/// base64 of an encrypted boolean (`FheBool`).
///
/// Requires the pact's `ServerKey` to be set on the current thread
/// (`tfhe::set_server_key`) before calling.
pub fn homomorphic_mutual_match(
    a_choice: &str,
    a_id: u32,
    b_choice: &str,
    b_id: u32,
) -> Result<String, String> {
    let a_ct: FheUint32 = decode_uint32(a_choice, "a_choice")?;
    let b_ct: FheUint32 = decode_uint32(b_choice, "b_choice")?;

    // a picked b, and b picked a — computed without decrypting either choice.
    let a_picked_b: FheBool = a_ct.eq(b_id);
    let b_picked_a: FheBool = b_ct.eq(a_id);
    let mutual: FheBool = a_picked_b & b_picked_a;

    let bytes = bincode::serialize(&mutual).map_err(|e| e.to_string())?;
    Ok(base64::Engine::encode(
        &base64::prelude::BASE64_STANDARD,
        &bytes,
    ))
}

fn decode_uint32(b64: &str, field: &str) -> Result<FheUint32, String> {
    let bytes = base64::Engine::decode(&base64::prelude::BASE64_STANDARD, b64)
        .map_err(|e| format!("invalid base64 for {field}: {e}"))?;
    bincode::deserialize(&bytes).map_err(|e| format!("invalid ciphertext for {field}: {e}"))
}

/// Opens the evaluator's encrypted-boolean verdict with the pact's `ClientKey`.
///
/// This is the ONLY sanctioned way to learn a pact outcome: the boolean is the
/// sole bit that ever leaves ciphertext, and only a pact-key holder can open
/// it. Interim trust model (pre-v9/M10): the server holds the arena key, so the
/// matcher service opens the verdict; once keys move client-side, this same
/// decrypt runs on-device instead.
pub fn decrypt_mutual_match(
    encrypted_match: &str,
    client_key: &tfhe::ClientKey,
) -> Result<bool, String> {
    let bytes = base64::Engine::decode(&base64::prelude::BASE64_STANDARD, encrypted_match)
        .map_err(|e| format!("invalid base64 for encrypted_match: {e}"))?;
    let ct: FheBool = bincode::deserialize(&bytes)
        .map_err(|e| format!("invalid ciphertext for encrypted_match: {e}"))?;
    Ok(ct.decrypt(client_key))
}
