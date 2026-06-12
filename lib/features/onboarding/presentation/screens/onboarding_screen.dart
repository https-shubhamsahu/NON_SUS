import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../providers/onboarding_providers.dart';
import '../widgets/interactive_onboarding_steps.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  String _getActLabel(int index) {
    switch (index) {
      case 0:
        return 'ACT 1: THE INCIDENT';
      case 1:
        return 'ACT 2: YOUR VAULT';
      case 2:
        return 'ACT 3: ENCLAVE LOCK';
      case 3:
        return 'ACT 4: IDENTITY';
      case 4:
        return 'ACT 5: PERSONA';
      case 5:
        return 'ACT 6: GET VERIFIED';
      default:
        return '';
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;
    final currentIndex = ref.watch(onboardingPageIndexProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getActLabel(currentIndex).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                  Text(
                    '${currentIndex + 1} / 6',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: fg.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            
            // Onboarding Slides PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 6,
                onPageChanged: (index) {
                  ref.read(onboardingPageIndexProvider.notifier).setIndex(index);
                },
                itemBuilder: (context, index) {
                  switch (index) {
                    case 0:
                      return OnboardingIncidentWidget(onNext: _nextPage);
                    case 1:
                      return OnboardingProtectWidget(onNext: _nextPage);
                    case 2:
                      return OnboardingSolutionWidget(onNext: _nextPage);
                    case 3:
                      return OnboardingIdentityWidget(onNext: _nextPage);
                    case 4:
                      return OnboardingPersonalizationWidget(onNext: _nextPage);
                    case 5:
                      return const OnboardingAuthWelcomeWidget();
                    default:
                      return Container();
                  }
                },
              ),
            ),

            // Footer controls
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered indicator above buttons
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: 6,
                      effect: WormEffect(
                        dotWidth: 6,
                        dotHeight: 6,
                        activeDotColor: fg,
                        dotColor: fg.withValues(alpha: 0.15),
                        spacing: 6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Left/Right actions
                if (currentIndex < 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back/Skip
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (currentIndex == 0) {
                              _pageController.animateToPage(
                                5,
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: fg.withValues(alpha: 0.15), width: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentIndex == 0 ? 'SKIP' : 'BACK',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                  color: fg.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Spacer placeholder
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
