/// Web OAuth client id for drive.file. Empty until
/// `--dart-define=GO_WEB_CLIENT_ID=...` is set; Drive connect stays off
/// until then, same pattern as crash reporting.
class GoConfig {
  GoConfig._();

  static const String webClientId = String.fromEnvironment('GO_WEB_CLIENT_ID');

  static bool get isConfigured => webClientId.isNotEmpty;

  static const String deskUrl = 'https://nosus.foo/go';
}
