import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void complete() {
    state = true;
  }

  void reset() {
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
