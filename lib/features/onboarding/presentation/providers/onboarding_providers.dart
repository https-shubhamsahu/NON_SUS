import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/secure_db_service.dart';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return SecureDbService.instance.isOnboardingCompleted();
  }

  void complete() {
    SecureDbService.instance.completeOnboarding();
    state = true;
  }
}

final onboardingCompletedProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingPageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int value) {
    state = value;
  }
}

final onboardingPageIndexProvider = NotifierProvider<OnboardingPageIndexNotifier, int>(
  OnboardingPageIndexNotifier.new,
);
