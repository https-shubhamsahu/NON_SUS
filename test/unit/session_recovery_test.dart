import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_sus/core/auth/session_recovery.dart';

void main() {
  group('SessionRecovery.isPermanentAuthFailure', () {
    test('treats missing refresh token as permanent', () {
      expect(
        SessionRecovery.isPermanentAuthFailure(
          const AuthException('Refresh token not found', code: 'refresh_token_not_found'),
        ),
        isTrue,
      );
    });

    test('does not treat network-shaped errors as logout', () {
      expect(SessionRecovery.isPermanentAuthFailure(Exception('SocketException')), isFalse);
      expect(
        SessionRecovery.isPermanentAuthFailure(
          const AuthException('JWT expired'),
        ),
        isFalse,
      );
    });
  });
}
