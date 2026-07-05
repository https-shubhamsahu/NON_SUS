import '../entities/arena_member.dart';
import '../entities/intent_kind.dart';
import '../entities/seal.dart';
import '../entities/sealed_match.dart';

/// Domain contract for the Sealed feature. Implementations live in `data/`.
abstract class SealedRepository {
  /// Join an arena, returning the caller's assigned public id (idempotent).
  Future<int> joinArena(String arenaId);

  /// The roster of an arena the caller belongs to.
  Future<List<ArenaMember>> arenaMembers(String arenaId);

  /// Seal an encrypted choice toward the member with [targetPublicId].
  ///
  /// NOTE (M2): the choice must be encrypted under the ARENA key (shared by both
  /// parties) for the pact predicate to evaluate. See `sealed_core.sql`.
  Future<Seal> sealChoice({
    required String arenaId,
    required int targetPublicId,
    IntentKind intentKind = IntentKind.crush,
  });

  /// The caller's own seals (RLS guarantees only these are returned).
  Future<List<Seal>> mySeals();

  /// Live stream of the caller's matches — the reveal moment.
  Stream<List<SealedMatch>> watchMatches();
}
