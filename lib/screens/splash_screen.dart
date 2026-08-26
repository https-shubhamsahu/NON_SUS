import 'package:flutter/material.dart';

/// A short, quiet transition between app launch and the first usable screen.
///
/// The web document paints a matching loader before Flutter starts. This
/// surface deliberately adds no extra product claims or blocking work; it is
/// only a visual hand-off while the app establishes its first frame.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.nextScreen});

  final Widget nextScreen;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) _navigateToNextScreen();
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navigateToNextScreen(),
      );
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 480;
            final markSize = compact ? 44.0 : 56.0;
            final verticalGap = compact ? 16.0 : 24.0;

            return Center(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: 'Preparing NO SUS workspace',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 352),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final progress = reducedMotion
                          ? 0.58
                          : 0.18 + (_controller.value * 0.64);
                      return Opacity(
                        opacity: reducedMotion
                            ? 1
                            : _controller.value.clamp(0.0, 1.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _BrandMark(size: markSize),
                            SizedBox(height: verticalGap),
                            Text(
                              'NO SUS',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Preparing your workspace',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: compact ? 20 : 28),
                            _ProgressRail(progress: progress),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'N',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.surface,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRail extends StatelessWidget {
  const _ProgressRail({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Loading',
      value: 'In progress',
      child: SizedBox(
        width: 184,
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: theme.colorScheme.outlineVariant,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: ColoredBox(color: theme.colorScheme.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
