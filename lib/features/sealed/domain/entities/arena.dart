/// A matching context. Members share one pact key; each member has a public id.
///
/// Maps to `public.arenas`.
class Arena {
  final String id;
  final String name;
  final String kind; // 'community' | 'pairwise'

  /// Non-secret CompactPublicKey (base64) for on-device encryption, if provisioned.
  final String? publicKey;

  const Arena({
    required this.id,
    required this.name,
    required this.kind,
    this.publicKey,
  });

  factory Arena.fromMap(Map<String, dynamic> map) => Arena(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        kind: map['kind'] as String? ?? 'community',
        publicKey: map['public_key'] as String?,
      );
}
