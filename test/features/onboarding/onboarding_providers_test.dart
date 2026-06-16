import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:no_sus/services/secure_db_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'Onboarding completed provider tracks and completes onboarding correctly',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state: onboarding should not be completed
      expect(container.read(onboardingCompletedProvider), false);
      expect(SecureDbService.instance.isOnboardingCompleted(), false);

      // Complete onboarding
      await container.read(onboardingCompletedProvider.notifier).complete();

      // Verify state updates to true
      expect(container.read(onboardingCompletedProvider), true);
      expect(SecureDbService.instance.isOnboardingCompleted(), true);
    },
  );

  test('Onboarding page index provider updates index correctly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial page index: 0
    expect(container.read(onboardingPageIndexProvider), 0);

    // Set page index
    container.read(onboardingPageIndexProvider.notifier).setIndex(5);

    // Verify page index updates
    expect(container.read(onboardingPageIndexProvider), 5);
  });

  test(
    'user type and guest mode are persisted by the app state service',
    () async {
      await SecureDbService.instance.loadPersistedState();
      await SecureDbService.instance.setUserType('educator');
      await SecureDbService.instance.setGuestMode(true);

      expect(SecureDbService.instance.userType, 'educator');
      expect(SecureDbService.instance.isGuestMode(), true);
    },
  );
}
