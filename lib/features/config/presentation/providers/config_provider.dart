import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../data/remote_config_service.dart';


/// Provider for the [RemoteConfigService] singleton.
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  final service = RemoteConfigService(Supabase.instance.client);
  ref.onDispose(() => service.dispose());
  return service;
});

/// FutureProvider to handle initialization of the remote config.
final configInitializerProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(remoteConfigServiceProvider);
  await service.initialize();
});

/// Family provider to check if a specific [flagKey] is enabled for the current user.
/// It watches the active authenticated user's ID to perform targeting checks.
final featureFlagProvider = Provider.family<bool, String>((ref, flagKey) {
  final user = ref.watch(authStateProvider).value;
  final service = ref.watch(remoteConfigServiceProvider);
  
  if (user == null) {
    return false;
  }
  
  return service.isFeatureEnabled(flagKey, user.id);
});

/// Family provider to get a remote configuration value.
final remoteConfigValueProvider = Provider.family<dynamic, _ConfigParam>((ref, param) {
  final service = ref.watch(remoteConfigServiceProvider);
  return service.getConfigValue(param.key, param.defaultValue);
});

/// FutureProvider to fetch the user role dynamically from user_roles table.
final userRoleProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 'user';
  
  try {
    final response = await Supabase.instance.client
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    return response?['role'] as String? ?? 'user';
  } catch (e) {
    debugLog('Config: Failed to fetch user role: $e');
    return 'user';
  }
});

/// Helper class for defining remote config parameters with defaults.
class _ConfigParam {
  final String key;
  final dynamic defaultValue;

  const _ConfigParam(this.key, this.defaultValue);
}

/// Predefined parameters for the SecureSend application configs.
class SecureSendConfigs {
  SecureSendConfigs._();

  static const maxExpiryDays = _ConfigParam(
    'securesend_max_expiry_days',
    30,
  );

  static const maxViewsDefault = _ConfigParam(
    'securesend_max_views_default',
    10,
  );

  static const minSupportedVersion = _ConfigParam(
    'min_supported_client_version',
    '1.0.0',
  );
}


