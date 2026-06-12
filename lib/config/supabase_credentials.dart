/// Configuration file hosting the credentials for the Supabase backend client.
///
/// Leave both [url] and [anonKey] empty to run the application in mock fallback mode.
///
/// To configure, create a `.env` file in the project root or set environment variables:
///   SUPABASE_URL=https://your-project.supabase.co
///   SUPABASE_ANON_KEY=your-anon-key
class SupabaseCredentials {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}
