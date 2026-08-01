import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mascot/mascot_controller.dart';
import '../core/mascot/mascot_state.dart';
import '../core/mascot/mascot_view.dart';
import '../core/providers/theme_provider.dart';

class VideoSplashScreen extends ConsumerStatefulWidget {
  final Widget nextScreen;

  const VideoSplashScreen({super.key, required this.nextScreen});

  @override
  ConsumerState<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends ConsumerState<VideoSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;
  final math.Random _random = math.Random(42);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToNextScreen();
      }
    });

    // Session bookend (see docs/design/MASCOT_MOTION_BIBLE.md): Lux+Nox wake
    // together only here and at logout — deferred a frame so this doesn't
    // mutate provider state mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(duoMascotProvider.notifier).play(MascotMood.wake);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    if (_navigated) return;
    if (mounted) {
      _navigated = true;
      ref.read(duoMascotProvider.notifier).play(MascotMood.returnToLogo);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.nextScreen,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isLight = themeMode == ThemeMode.light;

    return Scaffold(
      backgroundColor: isLight
          ? const Color(0xFFFAFAFA)
          : const Color(0xFF0A0A0A),
      // Tap anywhere skips the boot animation. Without an explicit label a
      // screen reader has nothing to announce here — the whole surface is a
      // CustomPaint, so the one available action would be invisible.
      body: Semantics(
        button: true,
        label: 'Skip intro',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _navigateToNextScreen,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Use a time-seeded random each frame for live noise
              final frameSeed = (_controller.value * 10000).toInt();
              return Stack(
                children: [
                  CustomPaint(
                    painter: PixelSplashPainter(
                      progress: _controller.value,
                      random: _random,
                      frameSeed: frameSeed,
                      isLight: isLight,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  // Fades in only as the boot sequence completes — the one
                  // moment Lux+Nox appear together, per the Scarcity rule.
                  if (_controller.value > 0.85)
                    Positioned(
                      bottom: 64,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Opacity(
                          opacity: ((_controller.value - 0.85) / 0.15).clamp(
                            0.0,
                            1.0,
                          ),
                          child: const MascotView(
                            character: MascotCharacter.duo,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class PixelSplashPainter extends CustomPainter {
  final double progress;
  final math.Random random;
  final int frameSeed;
  final bool isLight;

  PixelSplashPainter({
    required this.progress,
    required this.random,
    required this.frameSeed,
    this.isLight = true,
  });

  // Live per-frame random seeded by frameSeed
  math.Random get _live => math.Random(frameSeed);

  // NO SUS in 5x5 pixel art font
  static const List<List<int>> _noSusPixelText = [
    [
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      1,
    ],
    [
      1,
      1,
      0,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      0,
    ],
    [
      1,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
    ],
    [
      1,
      0,
      0,
      1,
      1,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
    ],
    [
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      1,
      1,
      1,
      0,
      0,
      0,
      1,
      1,
      1,
      0,
      0,
      1,
      1,
      1,
      1,
      0,
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final liveRng = _live;

    // ─── PHASE 0: BOOT STATIC (0.0 → 0.30) ───────────────────────────────────
    if (progress < 0.30) {
      final t = progress / 0.30; // 0→1 across phase
      const int pixelSize = 14;
      final int cols = (size.width / pixelSize).ceil();
      final int rows = (size.height / pixelSize).ceil();

      // a) Block static noise — density decreases as we approach logo reveal
      final double noiseDensity = 0.55 - t * 0.35;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (liveRng.nextDouble() < noiseDensity) {
            final grayVal = isLight
                ? (200 + liveRng.nextInt(47))
                : (8 + liveRng.nextInt(55));
            // Occasional color pop: red, blue, green channel glitch
            final colorBias = liveRng.nextInt(10);
            if (colorBias < 2) {
              paint.color = isLight
                  ? Color.fromARGB(255, grayVal - 30, grayVal, grayVal)
                  : Color.fromARGB(
                      255,
                      grayVal + 40,
                      grayVal ~/ 2,
                      grayVal ~/ 2,
                    );
            } else if (colorBias < 4) {
              paint.color = isLight
                  ? Color.fromARGB(255, grayVal, grayVal, grayVal - 30)
                  : Color.fromARGB(
                      255,
                      grayVal ~/ 2,
                      grayVal ~/ 2,
                      grayVal + 40,
                    );
            } else {
              paint.color = Color.fromARGB(255, grayVal, grayVal, grayVal);
            }
            canvas.drawRect(
              Rect.fromLTWH(
                c * pixelSize.toDouble(),
                r * pixelSize.toDouble(),
                pixelSize.toDouble() - 0.5,
                pixelSize.toDouble() - 0.5,
              ),
              paint,
            );
          }
        }
      }

      // b) Horizontal scan tears — fast horizontal strips that shift laterally
      final int tearCount = 4 + liveRng.nextInt(5);
      for (int i = 0; i < tearCount; i++) {
        final double tearY = liveRng.nextDouble() * size.height;
        final double tearH = 2.0 + liveRng.nextDouble() * 12.0;
        final double tearShift = (liveRng.nextDouble() - 0.5) * 80.0;
        final alpha = (liveRng.nextDouble() * 0.6 + 0.2);
        paint.color = isLight
            ? Color.fromARGB((alpha * 255).toInt(), 30, 30, 45)
            : Color.fromARGB((alpha * 255).toInt(), 200, 200, 220);
        canvas.save();
        canvas.translate(tearShift, 0);
        canvas.drawRect(Rect.fromLTWH(0, tearY, size.width, tearH), paint);
        canvas.restore();
      }

      // c) CRT scanlines (thin dark lines every 3px)
      paint.color = isLight ? const Color(0x0C000000) : const Color(0x22000000);
      for (double sy = 0; sy < size.height; sy += 3) {
        canvas.drawRect(Rect.fromLTWH(0, sy, size.width, 1), paint);
      }

      return;
    }

    // ─── PHASES 1 + 2: LOGO ASSEMBLY → DISSOLVE (0.30 → 1.0) ─────────────────
    final double mainT = (progress - 0.30) / 0.70; // 0→1
    final bool isDissolving = mainT > 0.75;
    final double dissolveT = isDissolving ? (mainT - 0.75) / 0.25 : 0.0;
    final double assembleT = isDissolving
        ? 1.0
        : (mainT / 0.75).clamp(0.0, 1.0);

    // 1. Dark/Light CRT noise background (persists at low density)
    const int bgPx = 28;
    final int bgCols = (size.width / bgPx).ceil();
    final int bgRows = (size.height / bgPx).ceil();
    for (int r = 0; r < bgRows; r++) {
      for (int c = 0; c < bgCols; c++) {
        if (liveRng.nextDouble() < 0.025) {
          paint.color = isLight
              ? const Color(0xFFF5F5F5)
              : const Color(0xFF141414);
          canvas.drawRect(
            Rect.fromLTWH(
              c * bgPx.toDouble(),
              r * bgPx.toDouble(),
              bgPx.toDouble(),
              bgPx.toDouble(),
            ),
            paint,
          );
        }
      }
    }

    // 2. CRT scanlines overlay
    paint.color = isLight ? const Color(0x0C000000) : const Color(0x15000000);
    for (double sy = 0; sy < size.height; sy += 3) {
      canvas.drawRect(Rect.fromLTWH(0, sy, size.width, 1), paint);
    }

    // 3. Random horizontal glitch tears (less frequent now)
    if (liveRng.nextDouble() < 0.3) {
      final double tearY = liveRng.nextDouble() * size.height;
      final double tearH = 1.0 + liveRng.nextDouble() * 6.0;
      final double tearShift = (liveRng.nextDouble() - 0.5) * 40.0;
      paint.color = isLight
          ? Color.fromARGB((40 + liveRng.nextInt(60)), 0, 0, 0)
          : Color.fromARGB((40 + liveRng.nextInt(60)), 255, 255, 255);
      canvas.save();
      canvas.translate(tearShift, 0);
      canvas.drawRect(Rect.fromLTWH(0, tearY, size.width, tearH), paint);
      canvas.restore();
    }

    // 4. Pixel-art logo with chromatic aberration + block jitter during assembly
    final double textBlockSize = (size.width * 0.82) / 31.0;
    final double textWidth = 31 * textBlockSize;
    final double textHeight = 5 * textBlockSize;
    final double textLeft = (size.width - textWidth) / 2.0;
    final double textTop = (size.height - textHeight) / 2.0 - 48.0;

    // Chromatic aberration offset — reduces as logo assembles
    final double aberrationOffset = (1.0 - assembleT).clamp(0.0, 1.0) * 6.0;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 31; col++) {
        if (_noSusPixelText[row][col] != 1) continue;

        // Base position
        double x = textLeft + col * textBlockSize;
        double y = textTop + row * textBlockSize;

        // Block jitter: each pixel arrives from a random direction
        if (!isDissolving && assembleT < 0.9) {
          // Use deterministic noise per pixel
          final seed = row * 31 + col;
          final jitterRng = math.Random(seed + frameSeed ~/ 100);
          final jitterAmt = (1.0 - assembleT) * 20.0;
          final jitterX = (jitterRng.nextDouble() - 0.5) * jitterAmt;
          final jitterY = (jitterRng.nextDouble() - 0.5) * jitterAmt;
          x += jitterX;
          y += jitterY;
        }

        if (isDissolving) {
          // Gravity + wind physics dissolve
          y +=
              dissolveT * dissolveT * size.height * 1.15 +
              math.sin(col * 2.0 + row) * 45.0 * dissolveT;
          x += math.sin(row * 4.0 + col) * 32.0 * dissolveT;
        }

        final double alpha = isDissolving
            ? (1.0 - dissolveT).clamp(0.0, 1.0)
            : assembleT.clamp(0.2, 1.0);
        final pxW = textBlockSize - 1.0;
        final pxH = textBlockSize - 1.0;

        // Draw chromatic aberration: red channel slightly left, blue slightly right
        if (aberrationOffset > 0.5) {
          paint.color = Color.fromARGB(
            (alpha * 0.5 * 255).toInt(),
            255,
            60,
            60,
          );
          canvas.drawRect(
            Rect.fromLTWH(x - aberrationOffset, y, pxW, pxH),
            paint,
          );

          paint.color = Color.fromARGB(
            (alpha * 0.5 * 255).toInt(),
            60,
            120,
            255,
          );
          canvas.drawRect(
            Rect.fromLTWH(x + aberrationOffset, y, pxW, pxH),
            paint,
          );
        }

        // Main pixel color
        paint.color = (isLight ? Colors.black : Colors.white).withValues(
          alpha: alpha,
        );
        canvas.drawRect(Rect.fromLTWH(x, y, pxW, pxH), paint);

        // Occasional pixel "spark" during assembly (random bright flicker)
        if (!isDissolving && liveRng.nextDouble() < 0.04) {
          paint.color = (isLight ? Colors.black : Colors.white).withValues(
            alpha: 0.7,
          );
          final sparkSize = textBlockSize * 1.4;
          canvas.drawRect(
            Rect.fromLTWH(
              x - sparkSize / 4,
              y - sparkSize / 4,
              sparkSize,
              sparkSize,
            ),
            paint,
          );
        }
      }
    }

    // 5. Loading bar with pixelated blocks
    final double barWidth = textWidth * 0.92;
    const double barHeight = 8.0;
    final double barLeft = (size.width - barWidth) / 2.0;
    final double barTop = textTop + textHeight + 56.0;

    final double loadPct = (mainT / 0.75).clamp(0.0, 1.0);
    final double barAlpha = isDissolving
        ? (1.0 - dissolveT).clamp(0.0, 1.0)
        : 0.22;

    // Border
    paint.color = (isLight ? Colors.black : Colors.white).withValues(
      alpha: barAlpha,
    );
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawRect(
      Rect.fromLTWH(barLeft - 3, barTop - 3, barWidth + 6, barHeight + 6),
      paint,
    );
    paint.style = PaintingStyle.fill;

    // Filled blocks
    const int blocksCount = 22;
    final double blockW = barWidth / blocksCount;
    final int activeBlocks = (blocksCount * loadPct).floor();
    for (int i = 0; i < activeBlocks; i++) {
      double bx = barLeft + i * blockW + 1.0;
      double by = barTop;
      if (isDissolving) {
        final double localT = dissolveT;
        by +=
            localT * localT * size.height * 1.15 +
            math.sin(i * 1.5) * 42.0 * localT;
        bx += math.sin(i.toDouble()) * 30.0 * localT;
      }
      final double fillAlpha = isDissolving
          ? (1.0 - dissolveT).clamp(0.0, 1.0)
          : 0.88;
      // Occasional flicker
      final flicker = liveRng.nextDouble();
      paint.color = flicker < 0.05
          ? (isLight ? Colors.black : Colors.white).withValues(
              alpha: fillAlpha * 0.3,
            )
          : (isLight ? Colors.black : Colors.white).withValues(
              alpha: fillAlpha,
            );
      canvas.drawRect(Rect.fromLTWH(bx, by, blockW - 2.0, barHeight), paint);
    }

    // 6. Console status text with glitch-type effect
    final String statusText = isDissolving
        ? 'SYS_DISINTEGRAT1NG...'
        : loadPct < 0.35
        ? 'SYS_B00TING_...'
        : loadPct < 0.70
        ? 'ENCLAVE_MOUNT1NG_...'
        : 'READY_T0_B00T_...';

    // Glitch swap characters randomly at low probability
    final glitchText = _maybGlitch(statusText, liveRng);

    final textPainter = TextPainter(
      text: TextSpan(
        text: glitchText,
        style: TextStyle(
          color: (isLight ? Colors.black : Colors.white).withValues(
            alpha: isDissolving ? (1.0 - dissolveT).clamp(0.0, 1.0) : 0.48,
          ),
          fontFamily: 'Courier',
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    double tx = (size.width - textPainter.width) / 2.0;
    double ty = barTop + barHeight + 22.0;

    if (isDissolving) {
      ty += dissolveT * dissolveT * size.height * 1.15;
      tx += math.sin(5.0) * 30.0 * dissolveT;
    } else if (liveRng.nextDouble() < 0.12) {
      // Subtle horizontal text jitter
      tx += (liveRng.nextDouble() - 0.5) * 4.0;
    }

    textPainter.paint(canvas, Offset(tx, ty));
    textPainter.dispose();

    // 7. Flash burst on first appear (very brief white/black flash)
    if (mainT < 0.05) {
      final double flashAlpha = (1.0 - mainT / 0.05).clamp(0.0, 1.0) * 0.6;
      paint.color = (isLight ? Colors.black : Colors.white).withValues(
        alpha: flashAlpha,
      );
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  /// Randomly swaps some characters with lookalike glitch chars for immersion.
  String _maybGlitch(String input, math.Random rng) {
    const glitchMap = {
      'O': '0',
      'I': '1',
      'E': '3',
      'A': '4',
      'G': '6',
      'T': '7',
      'S': '5',
      'B': '8',
    };
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      if (rng.nextDouble() < 0.08 && glitchMap.containsKey(ch)) {
        buf.write(glitchMap[ch]);
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }

  @override
  bool shouldRepaint(covariant PixelSplashPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.frameSeed != frameSeed;
  }
}
