import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/models/study_group.dart';
import '../../../theme.dart';
import 'member_avatar_stack.dart';

/// Premium group card with group name, meta info, stacked avatars, and security badge.
/// Provides press feedback via [_pressed] scale animation.
class GroupCard extends StatefulWidget {
  final StudyGroup group;
  final VoidCallback onTap;
  final int animationIndex;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.animationIndex = 0,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: NoSusTheme.s16,
                vertical: 14.0,
              ),
              decoration: NoSusTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Group name & Watermark Row ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.group.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.group.isWatermarkEnabled) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.water_drop_outlined,
                          size: 13,
                          color: subtle,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Description
                  Text(
                    widget.group.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: subtle.withValues(alpha: 0.85),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 14.0),

                  // ── Bottom row: avatars + stats ──────────────────────────────
                  Row(
                    children: [
                      MemberAvatarStack(
                        members: widget.group.members,
                        maxVisible: 3,
                        size: 24,
                      ),
                      const SizedBox(width: NoSusTheme.s12),
                      Text(
                        '${widget.group.memberCount} members',
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                      const Spacer(),
                      // File count pill
                      _MetaPill(
                        icon: Icons.description_outlined,
                        label: '${widget.group.fileCount}',
                        fg: fg,
                        subtle: subtle,
                      ),
                      const SizedBox(width: 8),
                      // Last activity
                      Text(
                        widget.group.lastActivityLabel,
                        style: TextStyle(fontSize: 11, color: subtle),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        )
        .animate(delay: (widget.animationIndex * 60).ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.04, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color subtle;

  const _MetaPill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: subtle),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: subtle)),
      ],
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

/// Shimmer loading placeholder matching the GroupCard layout.
class GroupCardSkeleton extends StatefulWidget {
  const GroupCardSkeleton({super.key});

  @override
  State<GroupCardSkeleton> createState() => _GroupCardSkeletonState();
}

class _GroupCardSkeletonState extends State<GroupCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEEEEEC);
    final highlight = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFFFFFFF);

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(NoSusTheme.s24),
          decoration: NoSusTheme.cardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Bone(
                    width: 72,
                    height: 18,
                    base: base,
                    highlight: highlight,
                    v: _shimmer.value,
                  ),
                  const Spacer(),
                  _Bone(
                    width: 18,
                    height: 18,
                    base: base,
                    highlight: highlight,
                    v: _shimmer.value,
                    radius: 9,
                  ),
                ],
              ),
              const SizedBox(height: NoSusTheme.s16),
              _Bone(
                width: 160,
                height: 16,
                base: base,
                highlight: highlight,
                v: _shimmer.value,
              ),
              const SizedBox(height: 8),
              _Bone(
                width: double.infinity,
                height: 12,
                base: base,
                highlight: highlight,
                v: _shimmer.value,
              ),
              const SizedBox(height: 5),
              _Bone(
                width: 180,
                height: 12,
                base: base,
                highlight: highlight,
                v: _shimmer.value,
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  _Bone(
                    width: 80,
                    height: 24,
                    base: base,
                    highlight: highlight,
                    v: _shimmer.value,
                    radius: 12,
                  ),
                  const Spacer(),
                  _Bone(
                    width: 60,
                    height: 12,
                    base: base,
                    highlight: highlight,
                    v: _shimmer.value,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final Color base;
  final Color highlight;
  final double v; // shimmer animation value 0–1
  final double radius;

  const _Bone({
    required this.width,
    required this.height,
    required this.base,
    required this.highlight,
    required this.v,
    this.radius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.5 + v * 3, 0),
          end: Alignment(-0.5 + v * 3, 0),
          colors: [base, highlight, base],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }
}
