import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class FloatingNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<NavTabItem> items = [
      NavTabItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Workspace',
      ),
      NavTabItem(
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        label: 'Vault',
      ),
      NavTabItem(
        icon: Icons.remove_red_eye_outlined,
        selectedIcon: Icons.remove_red_eye,
        label: 'Study Desk',
      ),
      NavTabItem(
        icon: Icons.history_edu_outlined,
        selectedIcon: Icons.history_edu,
        label: 'Audit Log',
      ),
      NavTabItem(
        icon: Icons.group_outlined,
        selectedIcon: Icons.group,
        label: 'Groups',
      ),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(
          left: NoSusTheme.s24,
          right: NoSusTheme.s24,
          bottom: NoSusTheme.s24,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NoSusTheme.r24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? NoSusTheme.dCard.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(NoSusTheme.r24),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = currentIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale: isSelected ? 1.15 : 1.0,
                              child: Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: NoSusTheme.s4),
                            Text(
                              item.label,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NavTabItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  NavTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
