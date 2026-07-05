/// FHE subsystem feature flags and endpoint configuration.
///
/// DESIGN RULES (see project architecture):
///   * Everything is DISABLED BY DEFAULT.
///   * There is NO single global "FHE on/off" switch used by callers — each
///     capability has its own granular flag so partial rollout is possible.
///   * Flags are compile-time constants sourced from `--dart-define` so a
///     release build ships with FHE off unless explicitly enabled, e.g.:
///
///       flutter run --dart-define-from-file=.env \
///         --dart-define=FHE_ENABLE_KEY_GENERATION=true \
///         --dart-define=FHE_ENABLE_BENCHMARKS=true
///
/// The Flutter app NEVER talks to TFHE-rs directly. All compute goes through
/// the Supabase `fhe-proxy` Edge Function, whose URL is derived from
/// SUPABASE_URL. A local override is available for on-device development
/// against a Rust service running on the host machine.
class FheConfig {
  FheConfig._();

  // ─── Granular capability flags (all default false) ─────────────────────────

  /// Allows the client to request/rotate FHE key material for the session.
  static const bool enableKeyGeneration =
      bool.fromEnvironment('FHE_ENABLE_KEY_GENERATION', defaultValue: false);

  /// Private AI Memory: encrypted similarity search over stored memories.
  static const bool enablePrivateMemory =
      bool.fromEnvironment('FHE_ENABLE_PRIVATE_MEMORY', defaultValue: false);

  /// Encrypted Policy Engine (backing "Selective Truth" enforcement).
  static const bool enablePolicyEngine =
      bool.fromEnvironment('FHE_ENABLE_POLICY_ENGINE', defaultValue: false);

  /// Homomorphic search over encrypted document metadata.
  static const bool enableHomomorphicSearch =
      bool.fromEnvironment('FHE_ENABLE_HOMOMORPHIC_SEARCH', defaultValue: false);

  /// Exposes the in-app benchmarking / "FHE Lab" demo surface.
  static const bool enableBenchmarks =
      bool.fromEnvironment('FHE_ENABLE_BENCHMARKS', defaultValue: false);

  /// Selective Truth end-user feature (decrypt only authorized sections).
  static const bool enableSelectiveTruth =
      bool.fromEnvironment('FHE_ENABLE_SELECTIVE_TRUTH', defaultValue: false);

  /// Sealed: the reciprocity-gated intent graph (the pivot product surface).
  /// Gates the `sealed` feature and its use of the pact mutual-match transport.
  /// Enable with `--dart-define=FHE_ENABLE_SEALED=true`.
  static const bool enableSealed =
      bool.fromEnvironment('FHE_ENABLE_SEALED', defaultValue: false);

  // ─── Derived helpers ────────────────────────────────────────────────────────

  /// True if ANY FHE capability is enabled. Used only for coarse UI gating
  /// (e.g. whether to show the Labs entry). Callers that perform actual
  /// cryptographic work must check the SPECIFIC capability flag instead.
  static bool get anyEnabled =>
      enableKeyGeneration ||
      enablePrivateMemory ||
      enablePolicyEngine ||
      enableHomomorphicSearch ||
      enableBenchmarks ||
      enableSelectiveTruth ||
      enableSealed;

  /// Backwards-compatibility shim for older call sites. Prefer the specific
  /// capability flags; this simply mirrors [anyEnabled].
  @Deprecated('Check a specific capability flag instead (e.g. enableBenchmarks)')
  static bool get isFheEnabled => anyEnabled;

  // ─── Endpoint configuration ─────────────────────────────────────────────────

  /// When true, the client hits a Rust service running directly on the dev
  /// host (bypassing Supabase) — useful for on-device debugging only.
  static const bool useLocalCompute =
      bool.fromEnvironment('FHE_USE_LOCAL_COMPUTE', defaultValue: false);

  /// Direct Rust service URL for local development. 10.0.2.2 maps to the host
  /// machine's localhost from the Android emulator.
  static const String localComputeUrl = String.fromEnvironment(
    'FHE_LOCAL_COMPUTE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Shared bearer token for local direct-mode development. This is never used
  /// by the production Supabase Edge Function path.
  static const String localServiceToken = String.fromEnvironment(
    'FHE_LOCAL_SERVICE_TOKEN',
    defaultValue: 'default-secure-fhe-token',
  );

  /// Name of the Supabase Edge Function that fronts the FHE microservice.
  static const String edgeFunctionName = 'fhe-proxy';
}
