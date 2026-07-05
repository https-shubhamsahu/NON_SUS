use crate::api::metrics::COMPUTE_REQUESTS;
use crate::compute;
use crate::compute::ComparisonEngine;
use crate::crypto;
use crate::crypto::{FheCryptosystem, TENANT_KEY_STORE, TFHEEngine};
use crate::models::{
    CompareRequest, ComputeRequest, ComputeResponse, DecryptRequest, EncryptRequest,
    JobStatusResponse, KeyGenRequest, KeyGenResponse, MemoryScore, MemorySearchRequest,
    MemorySearchResponse, MuxRequest, PactEvaluateRequest, PactEvaluateResponse,
    PolicyEvaluateRequest, PolicyEvaluateResponse, SimilarityRequest,
};
use crate::services;
use axum::{
    Json,
    extract::Path,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
};

/// Extracts the tenant id the `fhe-proxy` attaches via the `X-Tenant-Id` header
/// (the caller's Supabase user id). Falls back to a shared local-dev tenant when
/// the header is absent, so on-device direct-mode development still works.
fn tenant_id(headers: &HeaderMap) -> String {
    headers
        .get("x-tenant-id")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("local-dev-tenant")
        .to_string()
}

pub async fn generate_keys_handler(
    headers: HeaderMap,
    Json(payload): Json<KeyGenRequest>,
) -> impl IntoResponse {
    // Ensure real TFHE key material exists for this tenant (held in RAM only).
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);

    let serialized_params =
        crypto::initialize_parameters(payload.security_level, &payload.parameter_set);

    let response = KeyGenResponse {
        parameters_id: uuid::Uuid::new_v4().to_string(),
        serialized_parameters: serialized_params,
        public_fingerprint: keys.fingerprint.clone(),
    };

    (StatusCode::OK, Json(response))
}

/// Rotates the tenant's key material (generates a fresh set, dropping the old).
/// The proxy transitions the old `fhe_key_metadata` row to 'rotated' and inserts
/// a new 'active' row keyed by the returned fingerprint. Ciphertexts produced
/// under the previous keys are no longer decryptable, so the client must
/// re-encrypt after a rotation.
pub async fn rotate_keys_handler(
    headers: HeaderMap,
    Json(payload): Json<KeyGenRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.regenerate(&tenant);

    let serialized_params =
        crypto::initialize_parameters(payload.security_level, &payload.parameter_set);

    let response = KeyGenResponse {
        parameters_id: uuid::Uuid::new_v4().to_string(),
        serialized_parameters: serialized_params,
        public_fingerprint: keys.fingerprint.clone(),
    };

    (StatusCode::OK, Json(response))
}

/// Revokes the tenant's key material, dropping it from the in-memory store. The
/// proxy marks the `fhe_key_metadata` row 'revoked'. Idempotent: revoking when
/// no keys are cached still succeeds.
pub async fn revoke_keys_handler(headers: HeaderMap) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let had_keys = TENANT_KEY_STORE.revoke(&tenant);

    (
        StatusCode::OK,
        Json(serde_json::json!({ "status": "revoked", "had_active_keys": had_keys })),
    )
}

pub async fn compute_handler(
    headers: HeaderMap,
    Json(payload): Json<ComputeRequest>,
) -> impl IntoResponse {
    COMPUTE_REQUESTS.inc();

    // Verify ciphertext format integrity
    for ct in &payload.ciphertexts {
        if !crypto::verify_ciphertext_integrity(ct) {
            return (
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(ComputeResponse {
                    result_ciphertext: "Corrupted input ciphertext".to_string(),
                }),
            );
        }
    }

    // Load the tenant's evaluation (server) key onto this worker thread so the
    // homomorphic operations below run under the matching parameter set. The
    // ServerKey is set thread-locally by tfhe-rs for the duration of this call.
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let result = match payload.operation.to_uppercase().as_str() {
        "PRODUCT" => compute::homomorphic_product(&payload.ciphertexts),
        "SIMILARITY" | "DOT_PRODUCT" => {
            match compute::homomorphic_inner_product_split(&payload.ciphertexts) {
                Ok(result) => result,
                Err(err) => {
                    return (
                        StatusCode::UNPROCESSABLE_ENTITY,
                        Json(ComputeResponse {
                            result_ciphertext: err,
                        }),
                    );
                }
            }
        }
        _ => compute::homomorphic_sum(&payload.ciphertexts),
    };

    (
        StatusCode::OK,
        Json(ComputeResponse {
            result_ciphertext: result,
        }),
    )
}

pub async fn memory_search_handler(
    headers: HeaderMap,
    Json(payload): Json<MemorySearchRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let mut scores = vec![];
    for memory in payload.memories {
        let score_ciphertext =
            compute::homomorphic_inner_product(&payload.query_vector, &memory.vector);
        scores.push(MemoryScore {
            id: memory.id,
            encrypted_score: score_ciphertext,
        });
    }

    (StatusCode::OK, Json(MemorySearchResponse { scores }))
}

pub async fn policy_evaluate_handler(
    headers: HeaderMap,
    Json(payload): Json<PolicyEvaluateRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let masked_key = compute::homomorphic_policy_mux(
        &payload.user_encrypted_clearance,
        payload.doc_required_clearance,
        &payload.encrypted_aes_key,
    );

    (
        StatusCode::OK,
        Json(PolicyEvaluateResponse {
            masked_encrypted_aes_key: masked_key,
        }),
    )
}

pub async fn get_job_handler(Path(job_id): Path<String>) -> impl IntoResponse {
    match services::get_job(&job_id) {
        Some(job) => (StatusCode::OK, Json(job)),
        None => (
            StatusCode::NOT_FOUND,
            Json(JobStatusResponse {
                job_id,
                status: "not_found".to_string(),
                progress: 0.0,
                result: None,
            }),
        ),
    }
}

pub async fn submit_job_handler(
    headers: HeaderMap,
    Json(mut payload): Json<ComputeRequest>,
) -> impl IntoResponse {
    // The X-Tenant-Id header (set by fhe-proxy) is authoritative; it overrides
    // any tenant_id the request body may carry so a client can never evaluate
    // under another tenant's keys.
    payload.tenant_id = Some(tenant_id(&headers));
    match services::aggregation::DISTRIBUTED_QUEUE.submit_job(payload) {
        Ok(job_id) => (
            StatusCode::ACCEPTED,
            Json(serde_json::json!({
                "job_id": job_id,
                "status": "pending"
            })),
        )
            .into_response(),
        Err(err) => (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(serde_json::json!({
                "error": err
            })),
        )
            .into_response(),
    }
}

pub async fn cancel_job_handler(Path(job_id): Path<String>) -> impl IntoResponse {
    let cancelled = services::aggregation::DISTRIBUTED_QUEUE.cancel_job(&job_id);
    if cancelled {
        (
            StatusCode::OK,
            Json(serde_json::json!({
                "job_id": job_id,
                "status": "cancelled"
            })),
        )
            .into_response()
    } else {
        (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!({
                "job_id": job_id,
                "status": "cannot_cancel"
            })),
        )
            .into_response()
    }
}

pub async fn encrypt_handler(
    headers: HeaderMap,
    Json(payload): Json<EncryptRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    let engine = TFHEEngine;

    let ct = match engine.encrypt(payload.value, &keys.client_key) {
        Ok(ct) => ct,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": e })),
            );
        }
    };
    match engine.serialize_uint32(&ct) {
        Ok(bytes) => {
            let b64 = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &bytes);
            (
                StatusCode::OK,
                Json(serde_json::json!({ "ciphertext": b64 })),
            )
        }
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": e })),
        ),
    }
}

pub async fn decrypt_handler(
    headers: HeaderMap,
    Json(payload): Json<DecryptRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    let engine = TFHEEngine;

    let bytes = match base64::Engine::decode(&base64::prelude::BASE64_STANDARD, &payload.ciphertext)
    {
        Ok(bytes) => bytes,
        Err(_) => {
            return (
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(serde_json::json!({ "error": "Invalid base64 ciphertext" })),
            );
        }
    };
    let ct = match engine.deserialize_uint32(&bytes) {
        Ok(ct) => ct,
        Err(e) => {
            return (
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(serde_json::json!({ "error": e })),
            );
        }
    };
    match engine.decrypt(&ct, &keys.client_key) {
        Ok(val) => (StatusCode::OK, Json(serde_json::json!({ "value": val }))),
        Err(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({ "error": e })),
        ),
    }
}

pub async fn compare_handler(
    headers: HeaderMap,
    Json(payload): Json<CompareRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let comp_engine = crate::compute::ZamaComparisonEngine;
    let a = crate::compute::EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, &payload.ciphertext_a)
            .unwrap_or_default(),
    };
    let b = crate::compute::EncryptedUint32 {
        raw_bytes: base64::Engine::decode(&base64::prelude::BASE64_STANDARD, &payload.ciphertext_b)
            .unwrap_or_default(),
    };

    let res_ct = match payload.op.to_uppercase().as_str() {
        "EQ" => comp_engine.eq(&a, &b),
        "GT" => comp_engine.gt(&a, &b),
        _ => comp_engine.lt(&a, &b),
    };

    match res_ct {
        Ok(res) => {
            let b64 = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &res.raw_bytes);
            (
                StatusCode::OK,
                Json(serde_json::json!({ "result_ciphertext": b64 })),
            )
        }
        Err(err) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({ "error": err })),
        ),
    }
}

pub async fn mux_handler(headers: HeaderMap, Json(payload): Json<MuxRequest>) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let b64 = crate::compute::homomorphic_policy_mux(
        &payload.condition_ciphertext,
        0, // dummy
        &payload.true_ciphertext,
    );
    (
        StatusCode::OK,
        Json(serde_json::json!({ "result_ciphertext": b64 })),
    )
}

/// Evaluates a pairwise pact ("conditional revelation"). Both sealed choices are
/// under the arena's shared key, so the arena id is the key context here (not the
/// caller's tenant). Returns an encrypted boolean the parties can open with the
/// pact key. MVP trust model: the server holds the arena key — establishing that
/// key without a trusted party (two-party/threshold keygen) is the deferred "v9".
pub async fn pact_evaluate_handler(Json(payload): Json<PactEvaluateRequest>) -> impl IntoResponse {
    let keys = TENANT_KEY_STORE.get_or_create(&payload.arena_id);
    tfhe::set_server_key(keys.server_key.clone());

    match compute::homomorphic_mutual_match(
        &payload.a_choice,
        payload.a_id,
        &payload.b_choice,
        payload.b_id,
    ) {
        Ok(encrypted_match) => (
            StatusCode::OK,
            Json(PactEvaluateResponse { encrypted_match }),
        )
            .into_response(),
        Err(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({ "error": e })),
        )
            .into_response(),
    }
}

/// Seals a choice under an ARENA's pact key (the shared-key context `/encrypt`
/// cannot provide, since it keys on the caller tenant). Called by the trusted
/// matcher service when a member seals; the plaintext choice exists only in
/// transit and is never logged or persisted. Post-M10 this moves on-device.
pub async fn pact_seal_handler(
    Json(payload): Json<crate::models::PactSealRequest>,
) -> impl IntoResponse {
    let keys = TENANT_KEY_STORE.get_or_create(&payload.arena_id);
    let engine = TFHEEngine;

    let ct = match engine.encrypt(payload.choice, &keys.client_key) {
        Ok(ct) => ct,
        Err(e) => {
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({ "error": e })),
            )
                .into_response();
        }
    };
    match engine.serialize_uint32(&ct) {
        Ok(bytes) => {
            let b64 = base64::Engine::encode(&base64::prelude::BASE64_STANDARD, &bytes);
            (
                StatusCode::OK,
                Json(crate::models::PactSealResponse { sealed_choice: b64 }),
            )
                .into_response()
        }
        Err(e) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": e })),
        )
            .into_response(),
    }
}

/// Opens a pact verdict with the arena's pact key. The returned boolean is the
/// only bit that ever leaves ciphertext (see `compute::decrypt_mutual_match`).
pub async fn pact_decrypt_handler(
    Json(payload): Json<crate::models::PactDecryptRequest>,
) -> impl IntoResponse {
    let keys = TENANT_KEY_STORE.get_or_create(&payload.arena_id);

    match compute::decrypt_mutual_match(&payload.encrypted_match, &keys.client_key) {
        Ok(mutual) => (
            StatusCode::OK,
            Json(crate::models::PactDecryptResponse { mutual }),
        )
            .into_response(),
        Err(e) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({ "error": e })),
        )
            .into_response(),
    }
}

pub async fn similarity_handler(
    headers: HeaderMap,
    Json(payload): Json<SimilarityRequest>,
) -> impl IntoResponse {
    let tenant = tenant_id(&headers);
    let keys = TENANT_KEY_STORE.get_or_create(&tenant);
    tfhe::set_server_key(keys.server_key.clone());

    let b64 =
        crate::compute::homomorphic_inner_product(&payload.query_vector, &payload.memory_vector);
    (
        StatusCode::OK,
        Json(serde_json::json!({ "result_ciphertext": b64 })),
    )
}
