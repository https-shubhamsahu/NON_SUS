import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../fhe/data/fhe_transport.dart';
import '../../domain/entities/arena_member.dart';
import '../../domain/entities/intent_kind.dart';
import '../../domain/entities/seal.dart';
import '../../domain/entities/sealed_match.dart';
import '../../domain/repositories/sealed_repository.dart';
import '../sealed_api_client.dart';

/// Supabase-backed implementation of [SealedRepository].
///
/// Reads go straight to Postgres under RLS. Anything involving the arena pact
/// key (sealing, matching) or cross-user writes (invites) goes through the
/// trusted `sealed-api` Edge Function via [SealedApiClient].
class SupabaseSealedRepository implements SealedRepository {
  SupabaseSealedRepository(
    this._client,
    this._api, {
    FheTransport? fheTransport,
  }) : _fheTransport = fheTransport ?? FheTransport.instance;

  final SupabaseClient _client;
  final SealedApiClient _api;
  final FheTransport _fheTransport;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Signed-out: Sealed requires a session.');
    return id;
  }

  @override
  Future<void> saveProfile({required String handle, String? displayName}) async {
    await _client.from('sealed_profiles').upsert({
      'user_id': _userId,
      'handle': handle.trim().toLowerCase(),
      if (displayName != null) 'display_name': displayName,
    });
  }

  @override
  Future<String?> myHandle() async {
    final row = await _client
        .from('sealed_profiles')
        .select('handle')
        .eq('user_id', _userId)
        .maybeSingle();
    return row?['handle'] as String?;
  }

  @override
  Future<Map<String, String>> displayNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await _client
        .from('sealed_profiles')
        .select('user_id, handle, display_name')
        .inFilter('user_id', userIds);
    return {
      for (final r in rows)
        r['user_id'] as String:
            (r['display_name'] as String?) ?? (r['handle'] as String? ?? '?'),
    };
  }

  @override
  Future<({String arenaId, int myPublicId})> createArena(String name) =>
      _api.createArena(name);

  @override
  Future<int> joinArena(String arenaId) async {
    final result = await _client.rpc(
      'join_arena',
      params: {'p_arena_id': arenaId},
    );
    return (result as num).toInt();
  }

  @override
  Future<List<({String arenaId, String name, int myPublicId})>> myArenas() async {
    final rows = await _client
        .from('arena_members')
        .select('arena_id, arena_public_id, arenas(name)')
        .eq('user_id', _userId);
    return [
      for (final r in rows)
        (
          arenaId: r['arena_id'] as String,
          name: ((r['arenas'] as Map?)?['name'] as String?) ?? 'Arena',
          myPublicId: (r['arena_public_id'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<List<ArenaMember>> arenaMembers(String arenaId) async {
    final rows = await _client
        .from('arena_members')
        .select('user_id, arena_public_id')
        .eq('arena_id', arenaId)
        .order('arena_public_id');
    final members = [
      for (final r in rows) ArenaMember.fromMap(Map<String, dynamic>.from(r)),
    ];
    // Hydrate display names from the discoverable profile table.
    final names = await displayNames([for (final m in members) m.userId]);
    return [
      for (final m in members)
        ArenaMember(
          userId: m.userId,
          arenaPublicId: m.arenaPublicId,
          handle: names[m.userId],
          displayName: names[m.userId],
        ),
    ];
  }

  @override
  Future<bool> sealChoice({
    required String arenaId,
    required int targetPublicId,
    IntentKind intentKind = IntentKind.crush,
  }) async {
    // 1. Encrypt choice client-side using FheTransport (interim server key context fhe-proxy bridge)
    final response = await _fheTransport.send(
      'pact_seal',
      {
        'arena_id': arenaId,
        'choice': targetPublicId,
      },
    );
    final sealedChoice = response['sealed_choice'] as String;

    // 2. Persist the resulting ciphertext to the seals table directly via Supabase
    await _client.from('seals').upsert({
      'arena_id': arenaId,
      'sealer_id': _userId,
      'sealed_choice': sealedChoice,
      'intent_kind': intentKind.wire,
      'status': 'pending',
    });

    // 3. Trigger the trusted matcher directly (no DB webhook is configured on
    // `seals` INSERT yet — see PROJECT_HANDOVER.md). Best-effort: the poll
    // below is the authoritative check, so a matcher-invoke failure here must
    // never fail the whole seal.
    try {
      await _api.runMatcher(
        arenaId: arenaId,
        sealerId: _userId,
        sealedChoice: sealedChoice,
        intentKind: intentKind.wire,
      );
    } on Exception {
      // Swallow: a future DB webhook (or a retry) can still complete the
      // match; the poll loop below reflects the true state regardless.
    }

    // 4. Look up target's user_id from arena_members to check if a match was created.
    final targetMember = await _client
        .from('arena_members')
        .select('user_id')
        .eq('arena_id', arenaId)
        .eq('arena_public_id', targetPublicId)
        .maybeSingle();

    if (targetMember == null) return false;
    final targetUserId = targetMember['user_id'] as String;

    // Sort to match the DB constraint (user_a < user_b)
    final sorted = [_userId, targetUserId]..sort();
    final userA = sorted[0];
    final userB = sorted[1];

    // Poll for the match row (gives background matcher time to write matching results)
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      final matchRow = await _client
          .from('matches')
          .select('id')
          .eq('arena_id', arenaId)
          .eq('intent_kind', intentKind.wire)
          .eq('user_a', userA)
          .eq('user_b', userB)
          .maybeSingle();
      if (matchRow != null) {
        return true;
      }
    }
    return false;
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

  @override
  Future<String> createInvite({String? arenaId}) =>
      _api.createInvite(arenaId: arenaId);

  @override
  Future<({String? arenaId, int? myPublicId})> claimInvite(String code) =>
      _api.claimInvite(code);
}
