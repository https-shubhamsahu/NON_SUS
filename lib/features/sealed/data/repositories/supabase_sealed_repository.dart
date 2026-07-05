import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../fhe/data/fhe_transport.dart';
import '../../domain/entities/arena_member.dart';
import '../../domain/entities/intent_kind.dart';
import '../../domain/entities/seal.dart';
import '../../domain/entities/sealed_match.dart';
import '../../domain/repositories/sealed_repository.dart';

/// Supabase-backed implementation of [SealedRepository].
///
/// Pure-DB operations are complete. `sealChoice` wires the encrypt-then-persist
/// path; the arena-key correctness note is tracked for M2 (see sealed_core.sql).
class SupabaseSealedRepository implements SealedRepository {
  SupabaseSealedRepository(this._client, this._transport);

  final SupabaseClient _client;
  final FheTransport _transport;

  @override
  Future<int> joinArena(String arenaId) async {
    final result = await _client.rpc(
      'join_arena',
      params: {'p_arena_id': arenaId},
    );
    return (result as num).toInt();
  }

  @override
  Future<List<ArenaMember>> arenaMembers(String arenaId) async {
    final rows = await _client
        .from('arena_members')
        .select('user_id, arena_public_id')
        .eq('arena_id', arenaId)
        .order('arena_public_id');
    return rows
        .map((r) => ArenaMember.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<Seal> sealChoice({
    required String arenaId,
    required int targetPublicId,
    IntentKind intentKind = IntentKind.crush,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot seal while signed out.');
    }

    // Encrypt the chosen target's public id. TODO(M2): this must use the shared
    // ARENA key (not a per-user key) for the pact predicate to evaluate; the
    // interim server-side path is documented in sealed_core.sql.
    final encrypted = await _transport.send('encrypt', {
      'key_id': arenaId,
      'value': targetPublicId,
    });
    final ciphertext =
        (encrypted['ciphertext'] ?? encrypted['result'] ?? '').toString();

    final row = await _client
        .from('seals')
        .upsert({
          'arena_id': arenaId,
          'sealer_id': userId,
          'sealed_choice': ciphertext,
          'intent_kind': intentKind.wire,
        }, onConflict: 'arena_id,sealer_id,intent_kind')
        .select()
        .single();
    return Seal.fromMap(row);
  }

  @override
  Future<List<Seal>> mySeals() async {
    final rows = await _client
        .from('seals')
        .select()
        .order('created_at', ascending: false);
    return rows.map((r) => Seal.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  @override
  Stream<List<SealedMatch>> watchMatches() {
    return _client
        .from('matches')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .map((r) => SealedMatch.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }
}
