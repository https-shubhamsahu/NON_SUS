import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_credentials.dart';

/// Owns the one-time Supabase SDK initialization for the application.
final class SupabaseBootstrap {
  const SupabaseBootstrap._();

  static bool get isConfigured =>
      SupabaseCredentials.url.isNotEmpty &&
      SupabaseCredentials.anonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      throw StateError('Supabase credentials are not configured.');
    }

    await Supabase.initialize(
      url: SupabaseCredentials.url,
      publishableKey: SupabaseCredentials.anonKey,
    );
  }
}
