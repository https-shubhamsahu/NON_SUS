import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/theme_provider.dart';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      return ref.watch(sharedPreferencesProvider).getBool(AppConstants.kOnboardingKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  void complete() {
    try {
      ref.read(sharedPreferencesProvider).setBool(AppConstants.kOnboardingKey, true);
    } catch (_) {}
    state = true;
  }

  void reset() {
    try {
      ref.read(sharedPreferencesProvider).setBool(AppConstants.kOnboardingKey, false);
    } catch (_) {}
    state = false;
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

class TsecCommunityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final tsecCommunityProvider = NotifierProvider<TsecCommunityNotifier, bool>(
  TsecCommunityNotifier.new,
);
