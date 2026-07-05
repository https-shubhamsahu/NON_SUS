use criterion::{criterion_group, criterion_main, Criterion};
use tfhe::prelude::*;
use tfhe::{ConfigBuilder, ClientKey, ServerKey, FheUint32};

fn benchmark_tfhe_operations(c: &mut Criterion) {
    let config = ConfigBuilder::all_disabled()
        .enable_default_integers()
        .build();
    let client_key = ClientKey::generate(config);
    let server_key = ServerKey::new(&client_key);

    tfhe::set_server_key(server_key);

    let val_a = 45u32;
    let val_b = 15u32;

    let ct_a = FheUint32::try_encrypt(val_a, &client_key).unwrap();
    let ct_b = FheUint32::try_encrypt(val_b, &client_key).unwrap();

    c.bench_function("fhe_uint32_encryption", |b| {
        b.iter(|| {
            FheUint32::try_encrypt(val_a, &client_key).unwrap()
        })
    });

    c.bench_function("fhe_uint32_decryption", |b| {
        b.iter(|| {
            let _dec: u32 = ct_a.decrypt(&client_key);
        })
    });

    c.bench_function("fhe_uint32_addition", |b| {
        b.iter(|| {
            let _ct_add = &ct_a + &ct_b;
        })
    });

    c.bench_function("fhe_uint32_multiplication", |b| {
        b.iter(|| {
            let _ct_mul = &ct_a * &ct_b;
        })
    });

    c.bench_function("fhe_uint32_equality", |b| {
        b.iter(|| {
            let _ct_eq = ct_a.eq(&ct_b);
        })
    });

    c.bench_function("fhe_uint32_mux", |b| {
        let ct_eq = ct_a.eq(&ct_b);
        b.iter(|| {
            let _ct_mux = ct_eq.select(&ct_a, &ct_b);
        })
    });

    c.bench_function("fhe_uint32_serialization", |b| {
        b.iter(|| {
            let _serialized = bincode::serialize(&ct_a).unwrap();
        })
    });

    let serialized = bincode::serialize(&ct_a).unwrap();
    c.bench_function("fhe_uint32_deserialization", |b| {
        b.iter(|| {
            let _deserialized: FheUint32 = bincode::deserialize(&serialized).unwrap();
        })
    });

    c.bench_function("fhe_client_key_generation", |b| {
        b.iter(|| {
            let config = ConfigBuilder::all_disabled()
                .enable_default_integers()
                .build();
            let _client_key = ClientKey::generate(config);
        })
    });

    c.bench_function("fhe_server_key_generation", |b| {
        b.iter(|| {
            let _server_key = ServerKey::new(&client_key);
        })
    });

    c.bench_function("fhe_compact_public_key_generation", |b| {
        b.iter(|| {
            let _public_key = tfhe::CompactPublicKey::new(&client_key);
        })
    });
}

criterion_group!(benches, benchmark_tfhe_operations);
criterion_main!(benches);
