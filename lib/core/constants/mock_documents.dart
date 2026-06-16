/// Centralized mock document content for the Spyglass fallback viewer.
///
/// Previously triplicated across spyglass_viewer.dart, zero_trust_gateway.dart,
/// and groups_provider.dart. Now lives in one place.
library;

class MockDocuments {
  const MockDocuments._();

  static String getByTitle(String? title) {
    if (title == null) return defaultDocument;
    if (title.contains('Zero-Knowledge')) return zeroKnowledge;
    if (title.contains('AES-256-GCM')) return aesGcm;
    if (title.contains('System Architecture')) return systemArchitecture;
    return defaultDocument;
  }

  static const String zeroKnowledge =
      'Public-Key Cryptography / Introduction to Zero-Knowledge Proofs\n'
      'A Zero-Knowledge Proof (ZKP) allows a prover to convince a verifier that a statement is true '
      'without revealing any information beyond the validity of the statement itself.\n\n'
      'Key ZKP Properties\n'
      '1. Completeness: If the statement is true, an honest verifier will be convinced by an honest prover.\n'
      '2. Soundness: If the statement is false, no cheating prover can convince an honest verifier (except with tiny probability).\n'
      '3. Zero-Knowledge: If the statement is true, no verifier learns anything other than this fact.\n\n'
      'Applications in Privacy-Preserving Computations\n'
      'ZKPs are crucial in decentralized identity, anonymous transactions, and secure rollup chains. '
      'By verifying computations off-chain and only committing proofs on-chain, we achieve both high throughput and extreme privacy bounds.';

  static const String aesGcm =
      'Galois Counter Mode (GCM) / AES-256-GCM Hardware Performance\n'
      'Advanced Encryption Standard (AES) with Galois/Counter Mode (GCM) provides both confidentiality and data integrity.\n\n'
      'Hardware Acceleration\n'
      'Modern CPUs provide instructions (like Intel\'s AES-NI or ARMv8 Cryptography extensions) that execute rounds of AES in hardware. '
      'This mitigates cache-timing side-channel attacks by executing lookup tables in constant time.\n\n'
      'Galois Multiplier\n'
      'GCM utilizes universal hashing over a binary Galois field (GF(2^128)) for authentication. '
      'The PCLMULQDQ instruction performs carry-less multiplication of two 64-bit values, accelerating the Ghash calculation significantly.';

  static const String systemArchitecture =
      'Secure Enclave Infrastructure / System Architecture & Isolation\n'
      'Secure study enclaves rely on ring-0 isolation boundaries to ensure workspace integrity.\n\n'
      'Microkernel Principles\n'
      'To minimize the Trusted Computing Base (TCB), all non-essential OS services (such as drivers and filesystems) '
      'are executed in user space rather than kernel space.\n\n'
      'Memory Protection\n'
      'Intel SGX or AMD SEV isolate memory regions by hardware-encrypting RAM pages. Any unauthorized access from '
      'higher privilege rings triggers a processor exception, preventing memory inspection from rootkits or compromised hypervisors.';

  static const String defaultDocument =
      'Asymmetric Key Cryptography / Advanced Cryptography\n'
      'Public-Key Infrastructure uses a mathematically linked key pair: a public key that anyone may use to encrypt data, '
      'and a private key held exclusively by the recipient to decrypt it.\n\n'
      'Key Exchange — Diffie-Hellman\n'
      'The Diffie-Hellman key exchange allows two parties to establish a shared secret over an insecure channel without prior communication.\n\n'
      'Digital Signatures\n'
      'A digital signature provides authentication, integrity, and non-repudiation. RSA-PSS is the recommended padding scheme for RSA signatures. '
      'ECDSA with SHA-256 is preferred for compact signatures.';
}
