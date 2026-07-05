import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../fhe/data/fhe_transport.dart';
import '../../data/repositories/supabase_sealed_repository.dart';
import '../../domain/entities/arena_member.dart';
import '../../domain/entities/seal.dart';
import '../../domain/entities/sealed_match.dart';
import '../../domain/repositories/sealed_repository.dart';

/// Repository singleton for the Sealed feature.
final sealedRepositoryProvider = Provider<SealedRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSealedRepository(client, FheTransport.instance);
});

/// Roster of a given arena.
final arenaMembersProvider =
    FutureProvider.family<List<ArenaMember>, String>((ref, arenaId) {
  return ref.watch(sealedRepositoryProvider).arenaMembers(arenaId);
});

/// The current user's own seals.
final mySealsProvider = FutureProvider<List<Seal>>((ref) {
  return ref.watch(sealedRepositoryProvider).mySeals();
});

/// Live stream of the current user's matches — powers the reveal moment.
final matchesProvider = StreamProvider<List<SealedMatch>>((ref) {
  return ref.watch(sealedRepositoryProvider).watchMatches();
});
