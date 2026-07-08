import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Single transport for ALL Sealed traffic that needs trusted orchestration
/// (sealing under the arena pact key, matching, invites).
///
/// Mirrors the `FheTransport` pattern: `Supabase.functions.invoke('sealed-api')`
/// attaches the caller's JWT; the Edge Function authenticates, talks to the
/// Rust FHE service with the service token, and never exposes either to the app.
class SealedApiClient {
  SealedApiClient(this._client);

  final SupabaseClient _client;

  static const String _functionName = 'sealed-api';
  static const _uuid = Uuid();

  Future<Map<String, dynamic>> _send(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final res = await _client.functions.invoke(
      _functionName,
      body: {'action': action, 'payload': payload},
    );
    if (res.status != 200) {
      final detail = res.data is Map ? (res.data as Map)['error'] : res.data;
      throw Exception('sealed-api $action failed (${res.status}): $detail');
    }
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    throw Exception('Unexpected sealed-api response shape');
  }

  /// Creates an arena and joins the caller as public id 1.
  Future<({String arenaId, int myPublicId})> createArena(String name) async {
    final data = await _send('create_arena', {'name': name});
    return (
      arenaId: data['arena_id'] as String,
      myPublicId: (data['my_public_id'] as num).toInt(),
    );
  }

  /// Seals a choice toward [targetPublicId]; returns whether it matched now.
  Future<bool> seal({
    required String arenaId,
    required int targetPublicId,
    required String intentKind,
  }) async {
    final data = await _send('seal', {
      'arena_id': arenaId,
      'target_public_id': targetPublicId,
      'intent_kind': intentKind,
    });
    return data['matched'] == true;
  }

  /// Creates an unguessable invite code (optionally bound to an arena).
  Future<String> createInvite({String? arenaId}) async {
    final data = await _send('create_invite', {
      // ignore: use_null_aware_elements
      if (arenaId != null) 'arena_id': arenaId,
    });
    return data['code'] as String;
  }

  /// Claims an invite; joins its arena when one is attached.
  Future<({String? arenaId, int? myPublicId})> claimInvite(String code) async {
    final data = await _send('claim_invite', {'code': code});
    return (
      arenaId: data['arena_id'] as String?,
      myPublicId: (data['my_public_id'] as num?)?.toInt(),
    );
  }

  /// Directly triggers the trusted `pact-matcher` function for a seal just
  /// written by the caller. This is the client-side path that makes matching
  /// happen today, since no Supabase Database Webhook is configured yet on
  /// `seals` INSERT (see PROJECT_HANDOVER.md). Once a webhook is configured,
  /// this call becomes a redundant-but-harmless double-trigger — pact-matcher's
  /// match insert is idempotent (unique constraint + duplicate-key no-op).
  ///
  /// `pact-matcher` only permits a JWT-authenticated caller to trigger
  /// matching for their OWN [sealerId] (enforced server-side), so this can
  /// never be used to probe or reveal another user's match.
  Future<bool> runMatcher({
    required String arenaId,
    required String sealerId,
    required String sealedChoice,
    required String intentKind,
  }) async {
    final res = await _client.functions.invoke('pact-matcher', body: {
      'record': {
        // Required truthy by pact-matcher's payload check; the value itself
        // is never read (matching is keyed on arena_id + sealer_id).
        'id': _uuid.v4(),
        'arena_id': arenaId,
        'sealer_id': sealerId,
        'sealed_choice': sealedChoice,
        'intent_kind': intentKind,
        'status': 'pending',
      },
    });
    if (res.status != 200) return false;
    final data = res.data;
    return data is Map && data['matched'] == true;
  }
}
