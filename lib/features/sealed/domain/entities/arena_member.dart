/// A member of an arena, with the PUBLIC integer id used by the pact predicate.
///
/// Maps to `public.arena_members` (optionally joined with `sealed_profiles`).
class ArenaMember {
  final String userId;
  final int arenaPublicId;
  final String? handle;
  final String? displayName;

  const ArenaMember({
    required this.userId,
    required this.arenaPublicId,
    this.handle,
    this.displayName,
  });

  factory ArenaMember.fromMap(Map<String, dynamic> map) => ArenaMember(
        userId: map['user_id'] as String,
        arenaPublicId: (map['arena_public_id'] as num).toInt(),
        handle: map['handle'] as String?,
        displayName: map['display_name'] as String?,
      );
}
