import '../entities/arena_member.dart';
import '../entities/intent_kind.dart';
import '../entities/seal.dart';
import '../entities/sealed_match.dart';

/// Domain contract for the Sealed feature. Implementations live in `data/`.
abstract class SealedRepository {
  /// Claim/refresh the caller's public handle + display name.
  Future<void> saveProfile({required String handle, String? displayName});

  /// The caller's handle, or null if not yet claimed.
  Future<String?> myHandle();

  /// Display profiles (handle/display name) for a set of user ids.
  Future<Map<String, String>> displayNames(List<String> userIds);

  /// Create a new arena; caller becomes member with public id 1.
  Future<({String arenaId, int myPublicId})> createArena(String name);

  /// Join an arena, returning the caller's assigned public id (idempotent).
  Future<int> joinArena(String arenaId);

  /// Arenas the caller belongs to, with their public id in each.
  Future<List<({String arenaId, String name, int myPublicId})>> myArenas();

  /// The roster of an arena the caller belongs to.
  Future<List<ArenaMember>> arenaMembers(String arenaId);

  /// Seal an encrypted choice toward the member with [targetPublicId].
  /// Encryption happens server-side under the ARENA pact key (interim model);
  /// returns true when the seal produced a mutual match immediately.
  Future<bool> sealChoice({
    required String arenaId,
    required int targetPublicId,
    IntentKind intentKind = IntentKind.crush,
  });

  /// The caller's own seals (RLS guarantees only these are returned).
  Future<List<Seal>> mySeals();

  /// Live stream of the caller's matches — the reveal moment.
  Stream<List<SealedMatch>> watchMatches();

  /// Create an invite code (optionally bound to an arena) for the viral loop.
  Future<String> createInvite({String? arenaId});

  /// Claim an invite code; joins its arena when one is attached.
  Future<({String? arenaId, int? myPublicId})> claimInvite(String code);
}
