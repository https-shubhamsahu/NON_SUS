import 'intent_kind.dart';

/// A user's own encrypted, one-directional choice inside an arena.
///
/// Maps to `public.seals`. The client only ever sees ITS OWN seals (enforced by
/// RLS). The `sealed_choice` ciphertext is intentionally NOT modelled here —
/// the app never needs to read back its own ciphertext, and it must never be
/// treated as revealing the target.
class Seal {
  final String id;
  final String arenaId;
  final IntentKind intentKind;
  final String status; // 'pending' | 'matched' | 'withdrawn'
  final bool neverExpires;
  final DateTime createdAt;

  const Seal({
    required this.id,
    required this.arenaId,
    required this.intentKind,
    required this.status,
    required this.neverExpires,
    required this.createdAt,
  });

  bool get isMatched => status == 'matched';

  factory Seal.fromMap(Map<String, dynamic> map) => Seal(
        id: map['id'] as String,
        arenaId: map['arena_id'] as String,
        intentKind: IntentKind.fromWire(map['intent_kind'] as String? ?? 'crush'),
        status: map['status'] as String? ?? 'pending',
        neverExpires: map['never_expires'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
