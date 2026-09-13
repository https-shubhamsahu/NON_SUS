import 'package:flutter/material.dart';

/// Two-digit confirmation keypad. Auto-submits on the second digit.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  void _press(String digit) {
    if (!enabled) return;
    if (value.length >= 2) return;
    onChanged('$value$digit');
  }

  void _backspace() {
    if (!enabled || value.isEmpty) return;
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Slot(filled: value.isNotEmpty, char: value.isNotEmpty ? value[0] : null),
            const SizedBox(width: 16),
            _Slot(filled: value.length > 1, char: value.length > 1 ? value[1] : null),
          ],
        ),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final digit in row)
                  Expanded(
                    child: _Key(
                      label: digit,
                      onTap: () => _press(digit),
                    ),
                  ),
              ],
            ),
          ),
        Row(
          children: [
            const Expanded(child: SizedBox.shrink()),
            Expanded(
              child: _Key(label: '0', onTap: () => _press('0')),
            ),
            Expanded(
              child: _Key(
                label: '⌫',
                onTap: _backspace,
                color: fg.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.filled, this.char});
  final bool filled;
  final String? char;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Container(
      width: 72,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: filled ? 0.8 : 0.2), width: 1.4),
      ),
      child: Text(
        char ?? '',
        style: theme.textTheme.displayLarge?.copyWith(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap, this.color});
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 56,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: color ?? theme.colorScheme.onSurface,
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
