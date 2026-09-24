import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'group_drops_repository.dart';
import 'group_keys.dart';

/// Remote flag. Off: the CHAT tab is not shown and nothing here runs.
const groupDropsFlagKey = 'nosus_group_drops_enabled';

/// One key service per signed-in account; switching accounts drops every
/// cached group key with it.
final groupKeyServiceProvider = Provider<GroupKeyService>((ref) {
  ref.watch(authStateProvider.select((s) => s.value?.id));
  return GroupKeyService(
    api: SupabaseGroupKeyApi(ref.watch(supabaseClientProvider)),
    device: DeviceKeysGroupDevice(),
  );
});

final groupDropsRepositoryProvider = Provider<GroupDropsRepository>((ref) {
  return GroupDropsRepository(ref.watch(supabaseClientProvider));
});
