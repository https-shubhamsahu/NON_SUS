import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/supabase_share_repository.dart';
import '../../data/share_fetch_client.dart';
import '../../domain/repositories/share_repository.dart';

/// Repository singleton for creating/managing SecureSend share links.
/// (The anonymous viewing path never uses this — see [ShareFetchClient].)
final shareRepositoryProvider = Provider<ShareRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseShareRepository(client, ShareFetchClient.instance);
});
