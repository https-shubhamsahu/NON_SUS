import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:no_sus/features/fhe/data/fhe_transport.dart';
import 'package:no_sus/features/sealed/data/repositories/supabase_sealed_repository.dart';
import 'package:no_sus/features/sealed/data/sealed_api_client.dart';
import 'package:no_sus/features/sealed/domain/entities/intent_kind.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}
class MockPostgrestFilterBuilder<T> extends Mock
    implements PostgrestFilterBuilder<T> {}
class MockPostgrestTransformBuilder<T> extends Mock
    implements PostgrestTransformBuilder<T> {}
class MockFheTransport extends Mock implements FheTransport {}
class MockSealedApiClient extends Mock implements SealedApiClient {}

/// postgrest's builders implement `Future<T>` directly (there is no plain
/// async terminal method) — `await builder` desugars to `builder.then(...)`.
/// To fake a resolved value we stub `.then()` itself on the mock returned by
/// the last link in the chain, rather than the chain method that produced it.
void _resolveFilter<T>(MockPostgrestFilterBuilder<T> mock, T value) {
  when(() => mock.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as dynamic Function(T);
    // .then()'s contract requires returning a Future, not the bare value.
    return Future.value(onValue(value));
  });
}

void _resolveTransform<T>(MockPostgrestTransformBuilder<T> mock, T value) {
  when(() => mock.then<dynamic>(any(), onError: any(named: 'onError')))
      .thenAnswer((invocation) {
    final onValue = invocation.positionalArguments[0] as dynamic Function(T);
    return Future.value(onValue(value));
  });
}

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;
  late MockFheTransport mockFheTransport;
  late MockSealedApiClient mockSealedApi;
  late SupabaseSealedRepository repository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();
    mockFheTransport = MockFheTransport();
    mockSealedApi = MockSealedApiClient();

    // Setup Auth client stubs
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.id).thenReturn('user-a');

    repository = SupabaseSealedRepository(
      mockClient,
      mockSealedApi,
      fheTransport: mockFheTransport,
    );
  });

  test('sealChoice encrypts intent, persists to seals table, triggers the '
      'matcher, and polls for a match', () async {
    const arenaId = 'arena-uuid';
    const targetPublicId = 2;
    const intentKind = IntentKind.crush;

    // 1. Mock FheTransport pact_seal call returning the ciphertext
    when(() => mockFheTransport.send(
      'pact_seal',
      {
        'arena_id': arenaId,
        'choice': targetPublicId,
      },
    )).thenAnswer((_) async => {'sealed_choice': 'ciphertext-choice-a'});

    // 2. Mock seals table upsert (a bare await with no .select()/.maybeSingle())
    final mockSealsQueryBuilder = MockSupabaseQueryBuilder();
    final mockSealsFilterBuilder = MockPostgrestFilterBuilder<dynamic>();
    when(() => mockClient.from('seals')).thenAnswer((_) => mockSealsQueryBuilder);
    when(() => mockSealsQueryBuilder.upsert(any()))
        .thenAnswer((_) => mockSealsFilterBuilder);
    _resolveFilter<dynamic>(mockSealsFilterBuilder, null);

    // 2b. Mock the client-side pact-matcher trigger (closes the "nothing
    // invokes the matcher yet" gap — see PROJECT_HANDOVER.md).
    when(() => mockSealedApi.runMatcher(
      arenaId: any(named: 'arenaId'),
      sealerId: any(named: 'sealerId'),
      sealedChoice: any(named: 'sealedChoice'),
      intentKind: any(named: 'intentKind'),
    )).thenAnswer((_) async => true);

    // 3. Mock arena_members query to check target user_id
    final mockMembersQueryBuilder = MockSupabaseQueryBuilder();
    final mockMembersFilterBuilder1 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMembersFilterBuilder2 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMembersFilterBuilder3 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMembersTransform = MockPostgrestTransformBuilder<PostgrestMap?>();

    when(() => mockClient.from('arena_members'))
        .thenAnswer((_) => mockMembersQueryBuilder);
    when(() => mockMembersQueryBuilder.select('user_id'))
        .thenAnswer((_) => mockMembersFilterBuilder1);
    when(() => mockMembersFilterBuilder1.eq('arena_id', arenaId))
        .thenAnswer((_) => mockMembersFilterBuilder2);
    when(() => mockMembersFilterBuilder2.eq('arena_public_id', targetPublicId))
        .thenAnswer((_) => mockMembersFilterBuilder3);
    when(() => mockMembersFilterBuilder3.maybeSingle())
        .thenAnswer((_) => mockMembersTransform);
    _resolveTransform<PostgrestMap?>(mockMembersTransform, {'user_id': 'user-b'});

    // 4. Mock matches table check (polling) — each poll re-runs the chain, so
    // only the final `.maybeSingle()` needs a per-call result; a fresh
    // transform mock is returned (and resolved) on each of the 3 attempts.
    final mockMatchesQueryBuilder = MockSupabaseQueryBuilder();
    final mockMatchesFilterBuilder1 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMatchesFilterBuilder2 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMatchesFilterBuilder3 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMatchesFilterBuilder4 = MockPostgrestFilterBuilder<PostgrestList>();
    final mockMatchesFilterBuilder5 = MockPostgrestFilterBuilder<PostgrestList>();

    // Sorted: user-a < user-b
    when(() => mockClient.from('matches')).thenAnswer((_) => mockMatchesQueryBuilder);
    when(() => mockMatchesQueryBuilder.select('id'))
        .thenAnswer((_) => mockMatchesFilterBuilder1);
    when(() => mockMatchesFilterBuilder1.eq('arena_id', arenaId))
        .thenAnswer((_) => mockMatchesFilterBuilder2);
    when(() => mockMatchesFilterBuilder2.eq('intent_kind', intentKind.wire))
        .thenAnswer((_) => mockMatchesFilterBuilder3);
    when(() => mockMatchesFilterBuilder3.eq('user_a', 'user-a'))
        .thenAnswer((_) => mockMatchesFilterBuilder4);
    when(() => mockMatchesFilterBuilder4.eq('user_b', 'user-b'))
        .thenAnswer((_) => mockMatchesFilterBuilder5);

    // First two polls resolve to no row, third resolves to the match.
    var pollCount = 0;
    when(() => mockMatchesFilterBuilder5.maybeSingle()).thenAnswer((_) {
      pollCount++;
      final transform = MockPostgrestTransformBuilder<PostgrestMap?>();
      _resolveTransform<PostgrestMap?>(
        transform,
        pollCount >= 3 ? {'id': 'match-uuid'} : null,
      );
      return transform;
    });

    final matched = await repository.sealChoice(
      arenaId: arenaId,
      targetPublicId: targetPublicId,
      intentKind: intentKind,
    );

    expect(matched, isTrue);

    // Verify FheTransport.send was called with correct parameters
    verify(() => mockFheTransport.send(
      'pact_seal',
      {
        'arena_id': arenaId,
        'choice': targetPublicId,
      },
    )).called(1);

    // Verify seals upsert was called with correct encrypted value
    verify(() => mockSealsQueryBuilder.upsert({
      'arena_id': arenaId,
      'sealer_id': 'user-a',
      'sealed_choice': 'ciphertext-choice-a',
      'intent_kind': 'crush',
      'status': 'pending',
    })).called(1);

    // Verify the matcher was triggered directly for this seal (since no DB
    // webhook is configured on `seals` INSERT yet).
    verify(() => mockSealedApi.runMatcher(
      arenaId: arenaId,
      sealerId: 'user-a',
      sealedChoice: 'ciphertext-choice-a',
      intentKind: 'crush',
    )).called(1);
  });
}
