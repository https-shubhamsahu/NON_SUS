/// The kinds of intent a user can seal toward another person.
///
/// The wire values MUST match the `intent_kind` CHECK constraint in
/// `supabase/migrations/20260705000000_sealed_core.sql`.
enum IntentKind {
  crush,
  friend,
  reconnect,
  workWith,
  hire,
  invest,
  partner;

  /// Database/wire representation (snake_case).
  String get wire => switch (this) {
        IntentKind.crush => 'crush',
        IntentKind.friend => 'friend',
        IntentKind.reconnect => 'reconnect',
        IntentKind.workWith => 'work_with',
        IntentKind.hire => 'hire',
        IntentKind.invest => 'invest',
        IntentKind.partner => 'partner',
      };

  /// Human-facing label.
  String get label => switch (this) {
        IntentKind.crush => 'Crush',
        IntentKind.friend => 'Closer friends',
        IntentKind.reconnect => 'Reconnect',
        IntentKind.workWith => 'Work together',
        IntentKind.hire => 'Hire',
        IntentKind.invest => 'Invest',
        IntentKind.partner => 'Partner',
      };

  static IntentKind fromWire(String value) => IntentKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => IntentKind.crush,
      );
}
