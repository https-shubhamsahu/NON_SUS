import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingIncidentWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingIncidentWidget({super.key, required this.onNext});

  @override
  State<OnboardingIncidentWidget> createState() =>
      _OnboardingIncidentWidgetState();
}

class PixelFile {
  double x;
  double y;
  double vx;
  double vy;
  double angle;
  double rotSpeed;
  PixelFile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.rotSpeed,
  });
}

class _OnboardingIncidentWidgetState extends State<OnboardingIncidentWidget> {
  final List<PixelFile> _files = [];
  Timer? _timer;
  int _tapCount = 0;
  final double _gravity = 0.6;
  final double _bounce = -0.45;
  final double _friction = 0.98;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = 380.0; // clamp height area

        for (final file in _files) {
          file.vy += _gravity;
          file.x += file.vx;
          file.y += file.vy;
          file.vx *= _friction;
          file.angle += file.rotSpeed;

          // Bottom collision
          if (file.y > screenHeight) {
            file.y = screenHeight;
            file.vy = file.vy * _bounce;
            file.rotSpeed *= 0.5;
            if (file.vy.abs() < 1) file.vy = 0;
          }

          // Side collisions
          if (file.x < 0) {
            file.x = 0;
            file.vx = -file.vx * 0.7;
          } else if (file.x > screenWidth - 40) {
            file.x = screenWidth - 40;
            file.vx = -file.vx * 0.7;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _spawnFiles() {
    HapticFeedback.lightImpact();
    final rand = math.Random();
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() {
      _tapCount++;
      // Spawn 3 files with varying velocities
      for (int i = 0; i < 3; i++) {
        _files.add(
          PixelFile(
            x: screenWidth / 2 - 20,
            y: 120,
            vx: rand.nextDouble() * 12 - 6,
            vy: rand.nextDouble() * -10 - 5,
            angle: rand.nextDouble() * math.pi,
            rotSpeed: rand.nextDouble() * 0.2 - 0.1,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(
          'THAT ESCALATED QUICKLY.',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: fg,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Most leaks don\'t start with bad intentions. One click turns a small share into an uncontrollable flood.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: fg.withValues(alpha: 0.6),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Interactive Canvas
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Interactive tap target document (idle float)
              Align(
                alignment: const Alignment(0, -0.6),
                child: GestureDetector(
                  onTap: _spawnFiles,
                  child:
                      Container(
                            width: 72,
                            height: 84,
                            decoration: BoxDecoration(
                              border: Border.all(color: fg, width: 1.8),
                              borderRadius: BorderRadius.circular(6),
                              color: isDark ? Colors.black : Colors.white,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.description_outlined,
                                size: 36,
                                color: fg,
                              ),
                            ),
                          )
                          .animate(
                            onPlay: (controller) =>
                                controller.repeat(reverse: true),
                          )
                          .slideY(
                            begin: 0,
                            end: -0.08,
                            duration: 1200.ms,
                            curve: Curves.easeInOutSine,
                          ),
                ),
              ),

              // Scattered Duplicated Files
              ..._files.map((file) {
                return Positioned(
                  left: file.x,
                  top: file.y,
                  child: Transform.rotate(
                    angle: file.angle,
                    child: Container(
                      width: 36,
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: fg.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      child: Icon(
                        Icons.description,
                        size: 18,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Microcopy and Next Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              Text(
                'TAP THE FILE ABOVE TO SHARE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: fg.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: widget.onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _tapCount >= 3 ? 'CONTINUE HANDSHAKE' : 'SKIP INTRO',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
