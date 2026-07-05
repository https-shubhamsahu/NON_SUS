import 'intent_kind.dart';

/// A mutual match — created by the matcher ONLY when the FHE predicate decrypts
/// true. Visible (via RLS) to the two participants only.
///
/// Maps to `public.matches`.
class SealedMatch {
  final String id;
  final String arenaId;
  final String userA;
  final String userB;
  final IntentKind intentKind;
  final DateTime matchedAt;

  const SealedMatch({
    required this.id,
    required this.arenaId,
    required this.userA,
    required this.userB,
    required this.intentKind,
    required this.matchedAt,
  });

  /// The other participant, relative to the current user.
  String otherUserId(String me) => me == userA ? userB : userA;

  factory SealedMatch.fromMap(Map<String, dynamic> map) => SealedMatch(
        id: map['id'] as String,
        arenaId: map['arena_id'] as String,
        userA: map['user_a'] as String,
        userB: map['user_b'] as String,
        intentKind: IntentKind.fromWire(map['intent_kind'] as String? ?? 'crush'),
        matchedAt: DateTime.parse(map['matched_at'] as String),
      );
}
