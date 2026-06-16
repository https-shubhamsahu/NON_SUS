import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:no_sus/theme.dart';

class OnboardingSolutionWidget extends StatefulWidget {
  final VoidCallback onNext;
  const OnboardingSolutionWidget({super.key, required this.onNext});

  @override
  State<OnboardingSolutionWidget> createState() =>
      _OnboardingSolutionWidgetState();
}

class _OnboardingSolutionWidgetState extends State<OnboardingSolutionWidget>
    with SingleTickerProviderStateMixin {
  bool _isDropped = false;
  bool _groupChecked = false;
  bool _accountChecked = false;
  bool _trackChecked = false;
  bool _watermarkChecked = false;
  AnimationController? _vaultSlamController;

  @override
  void initState() {
    super.initState();
    _vaultSlamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _vaultSlamController?.dispose();
    super.dispose();
  }

  void _onDrop() async {
    HapticFeedback.heavyImpact();
    setState(() => _isDropped = true);
    _vaultSlamController?.forward();

    // Sequentially check features with delays
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _groupChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _accountChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _trackChecked = true);
    HapticFeedback.selectionClick();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _watermarkChecked = true);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'LOCK IT DOWN.',
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
            'Drag the file into the vault to encrypt and track.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              color: fg.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Draggable/Target Canvas
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isDropped)
                  Draggable<String>(
                        data: 'file',
                        feedback: Material(
                          color: Colors.transparent,
                          child: Container(
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
                          ),
                        ),
                        childWhenDragging: Container(
                          width: 72,
                          height: 84,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: fg.withValues(alpha: 0.15),
                              width: 1.8,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Container(
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
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .slideY(
                        begin: 0,
                        end: -0.05,
                        duration: 1.seconds,
                        curve: Curves.easeInOutSine,
                      )
                else
                  const SizedBox(height: 84),
                const SizedBox(height: 48),

                // Vault target
                DragTarget<String>(
                  onWillAcceptWithDetails: (details) => !_isDropped,
                  onAcceptWithDetails: (details) => _onDrop(),
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;

                    return AnimatedBuilder(
                      animation: _vaultSlamController!,
                      builder: (context, child) {
                        final slamScale =
                            1.0 +
                            (0.15 *
                                math.sin(
                                  _vaultSlamController!.value * math.pi,
                                ));
                        return Transform.scale(
                          scale: isHovering ? 1.08 : slamScale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isDropped
                                    ? fg
                                    : fg.withValues(alpha: 0.5),
                                width: _isDropped ? 2.2 : 1.5,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: isHovering
                                  ? fg.withValues(alpha: 0.05)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              _isDropped
                                  ? Icons.lock_outline
                                  : Icons.lock_open_outlined,
                              size: 48,
                              color: _isDropped
                                  ? fg
                                  : fg.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Sequenced Checkbox outputs
          if (_isDropped)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                children: [
                  _buildTickLine('Private Groups', _groupChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Viewer Accountability', _accountChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Activity Tracking', _trackChecked, fg),
                  const SizedBox(height: 10),
                  _buildTickLine('Dynamic Watermarks', _watermarkChecked, fg),
                ],
              ),
            ),
          const SizedBox(height: 24),

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
                  _watermarkChecked ? 'BUILD IDENTITY' : 'SKIP TO IDENTITY',
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTickLine(String text, bool ticked, Color fg) {
    return AnimatedOpacity(
      opacity: ticked ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: ticked ? const Color(0xFF10B981) : fg,
            size: 16,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: fg.withValues(alpha: ticked ? 0.95 : 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
