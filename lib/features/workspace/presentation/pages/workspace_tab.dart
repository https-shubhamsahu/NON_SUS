import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme.dart';
import '../../../../components/study_chart.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../../../services/supabase_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../notes/providers/notes_provider.dart';
import '../../../focus/providers/focus_provider.dart';
import '../../providers/recently_saved_provider.dart';
import '../../../files/presentation/providers/upload_provider.dart';
import '../../../share/presentation/screens/burn_note_creator_screen.dart';
/// Tab 0 — Workspace Dashboard
/// Welcome banner + Study chart + Secure notepad.
class WorkspaceTab extends ConsumerStatefulWidget {
  const WorkspaceTab({super.key});

  @override
  ConsumerState<WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends ConsumerState<WorkspaceTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _noteController = TextEditingController(
    text: AppConstants.defaultNoteContent,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null && mounted) {
        final content = await SupabaseService.instance.fetchUserNote(user.id);
        if (mounted) {
          ref.read(userNoteProvider.notifier).loadNote(user.id);
          _noteController.text = content.isNotEmpty
              ? content
              : AppConstants.defaultNoteContent;
        }
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black;

    final authState = ref.watch(authStateProvider);
    final userEmail = authState.value?.email ?? 'Student Guest';
    final profileAsync = ref.watch(profileProvider);
    final displayName = profileAsync.maybeWhen(
      data: (p) => p.displayName,
      orElse: () => userEmail.contains('@')
          ? userEmail.split('@').first
          : 'Student Guest',
    );
    final isLive =
        SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(studyTimelineProvider);
        ref.invalidate(userNoteProvider);
        await ref.read(studyTimelineProvider.future);
      },
      color: fg,
      backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
      child: ListView(
        key: const ValueKey('workspace_tab'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Welcome + Status Banner ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(NoSusTheme.s24),
            decoration: NoSusTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${displayName.toUpperCase()}',
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: NoSusTheme.s4),
                Text(
                  userEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s12),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLive ? const Color(0xFF10B981) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      isLive
                          ? 'Live Encrypted Workspace'
                          : 'Offline Fallback Mode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: NoSusTheme.s16),

          const _SealedTeaserCard()
              .animate()
              .fadeIn(duration: 340.ms)
              .slideY(begin: 0.05, end: 0),
          const SizedBox(height: NoSusTheme.s16),

          const _BurnNoteTeaserCard()
              .animate()
              .fadeIn(duration: 370.ms)
              .slideY(begin: 0.05, end: 0),
          const SizedBox(height: NoSusTheme.s16),

          // ── Study Chart ──────────────────────────────────────────────────────
          SizedBox(
            height: 200,
            child: const StudyChart()
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.05, end: 0),
          ),

          const SizedBox(height: NoSusTheme.s16),

          // ── Recently Saved ───────────────────────────────────────────────────
          const _RecentlySavedSection()
              .animate()
              .fadeIn(duration: 450.ms)
              .slideY(begin: 0.05, end: 0),

          const SizedBox(height: NoSusTheme.s16),

          // ── Secure Notepad ───────────────────────────────────────────────────
          SizedBox(
            height: 280,
            child: _SecurePad(
              controller: _noteController,
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),
          ),
        ],
      ),
    );
  }
}

// ─── Secure Notepad ───────────────────────────────────────────────────────────

class _SecurePad extends ConsumerWidget {
  final TextEditingController controller;
  const _SecurePad({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSaving = ref.watch(userNoteProvider).isSaving;

    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SECURE PAD',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              AnimatedOpacity(
                opacity: isSaving ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'SAVING...',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.amber,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: NoSusTheme.s16),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              onChanged: (text) =>
                  ref.read(userNoteProvider.notifier).updateNote(text),
              cursorColor: theme.colorScheme.onSurface,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'Courier',
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Start writing private study logs...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SealedTeaserCard extends StatefulWidget {
  const _SealedTeaserCard();

  @override
  State<_SealedTeaserCard> createState() => _SealedTeaserCardState();
}

class _SealedTeaserCardState extends State<_SealedTeaserCard> {
  bool _submitted = false;

  void _showDemoSheet(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _SealedDemoSheet(),
    ).then((completed) {
      if (completed == true) {
        if (!mounted) return;
        setState(() {
          _submitted = true;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your validation has been recorded.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.purple,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;

    return Container(
      width: double.infinity,
      decoration: NoSusTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withValues(alpha: isDark ? 0.15 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(NoSusTheme.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'SEALED v1.0',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.purpleAccent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (_submitted)
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'VALIDATED',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'INTERACTIVE PREVIEW',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: 8,
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: NoSusTheme.s16),
                Text(
                  'THE RECIPROCITY-GATED INTENT GRAPH',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: NoSusTheme.s8),
                Text(
                  'Share documents securely under conditional terms. Recipients must agree to share their corresponding documents back to gain access.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg.withValues(alpha: 0.6),
                    height: 1.4,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showDemoSheet(context),
                    icon: Icon(
                      _submitted ? Icons.replay_outlined : Icons.play_arrow_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _submitted ? 'REPLAY INTERACTIVE PREVIEW' : 'START INTERACTIVE DEMO',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SealedDemoSheet extends StatefulWidget {
  const _SealedDemoSheet();

  @override
  State<_SealedDemoSheet> createState() => _SealedDemoSheetState();
}

class _SealedDemoSheetState extends State<_SealedDemoSheet> {
  int _step = 0; // 0: intro, 1: rules, 2: simulation, 3: validation
  String? _selectedRule;
  final Set<String> _benefits = {};
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();

  final List<String> _rules = [
    'Mutual Disclosure (Require reciprocal file upload)',
    'Identity Escrow (Unlock only with verified institutional credentials)',
    'Time-Locked Deposit (Verify study time before opening)',
  ];

  final List<String> _benefitOptions = [
    'Eliminates trust issues in study sharing',
    'Increases collaborative document exchange',
    'Perfect for sensitive IP or research drafts',
    'Simplifies compliance & security checks',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Widget _buildIntro() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shield_outlined, size: 40, color: Colors.purpleAccent),
        const SizedBox(height: 16),
        Text(
          'WHAT IS SEALED?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Conventional document sharing is one-way: you share your file, and they take it without giving anything back.\n\n'
          'Sealed implements a Reciprocity Gate. You lock your file under a specific rule (e.g. "Mutual Disclosure"). The recipient can see a blurred preview but cannot unlock the full file unless they upload a corresponding document in return.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: fg.withValues(alpha: 0.7),
            height: 1.5,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () => setState(() => _step = 1),
            child: const Text('NEXT: SET A RULE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildRules() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.rule_folder_outlined, size: 40, color: Colors.purpleAccent),
        const SizedBox(height: 16),
        Text(
          'STEP 1: CHOOSE A RECIPROCITY RULE',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the condition the recipient must fulfill to unlock your file:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: fg.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        ..._rules.map((rule) {
          final isSelected = _selectedRule == rule;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedRule = rule),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.purpleAccent : fg.withValues(alpha: 0.12),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  color: isSelected
                      ? Colors.purple.withValues(alpha: 0.05)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? Colors.purpleAccent : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('BACK', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: _selectedRule == null
                    ? null
                    : () => setState(() => _step = 2),
                child: const Text('NEXT: MATCH INTENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimulation() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.share_arrival_time_outlined, size: 40, color: Colors.purpleAccent),
        const SizedBox(height: 16),
        Text(
          'STEP 2: SIMULATING THE INTENT MATCH',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Watch the reciprocity graph exchange credentials in real time:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: fg.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            height: 160,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fg.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.insert_drive_file, size: 28, color: Colors.purpleAccent),
                    const SizedBox(height: 6),
                    Text(
                      'Your Document',
                      style: theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
                Icon(Icons.swap_horiz, size: 32, color: fg.withValues(alpha: 0.5))
                    .animate(onPlay: (c) => c.repeat())
                    .slideX(begin: -0.15, end: 0.15, duration: 1500.ms, curve: Curves.easeInOut)
                    .then()
                    .slideX(begin: 0.15, end: -0.15, duration: 1500.ms, curve: Curves.easeInOut),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 28, color: Colors.grey),
                    const SizedBox(height: 6),
                    Text(
                      'Locked Recipient',
                      style: theme.textTheme.labelMedium?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.05),
            border: Border.all(color: Colors.green, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, color: Colors.green, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Simulation: Recipient uploaded matching file. Intent satisfied, document decrypted!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('BACK', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.purple),
                onPressed: () => setState(() => _step = 3),
                child: const Text('VALIDATE FEATURE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValidation() {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.rate_review_outlined, size: 40, color: Colors.purpleAccent),
          const SizedBox(height: 16),
          Text(
            'USER VALIDATION',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback helps us decide if we should ship this feature. Please rate your interest:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final filled = starIndex <= _rating;
              return IconButton(
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? Colors.purpleAccent : Colors.grey,
                  size: 32,
                ),
                onPressed: () => setState(() => _rating = starIndex),
              );
            }),
          ),
          const SizedBox(height: 20),
          Text(
            'How would this feature help your workflow?',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._benefitOptions.map((benefit) {
            final isSelected = _benefits.contains(benefit);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(benefit, style: const TextStyle(fontSize: 12)),
              value: isSelected,
              activeColor: Colors.purpleAccent,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _benefits.add(benefit);
                  } else {
                    _benefits.remove(benefit);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 16),
          Text(
            'Suggestions or Feedback (optional)',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'What would make you love this feature?',
              hintStyle: TextStyle(color: fg.withValues(alpha: 0.35), fontSize: 12),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.purple),
              onPressed: _rating == 0
                  ? null
                  : () {
                      Navigator.pop(context, true);
                    },
              child: const Text('SUBMIT VALIDATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            switch (_step) {
              0 => _buildIntro(),
              1 => _buildRules(),
              2 => _buildSimulation(),
              _ => _buildValidation(),
            },
          ],
        ),
      ),
    );
  }
}

class _RecentlySavedSection extends ConsumerWidget {
  const _RecentlySavedSection();

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'text':
        return Icons.note_alt_outlined;
      case 'url':
        return Icons.link_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    if (isDark) {
      switch (type) {
        case 'pdf':
          return Colors.red[300]!;
        case 'image':
          return Colors.blue[300]!;
        case 'text':
          return Colors.green[300]!;
        case 'url':
          return Colors.amber[300]!;
        default:
          return Colors.grey[300]!;
      }
    } else {
      switch (type) {
        case 'pdf':
          return Colors.red[700]!;
        case 'image':
          return Colors.blue[700]!;
        case 'text':
          return Colors.green[700]!;
        case 'url':
          return Colors.amber[700]!;
        default:
          return Colors.grey[700]!;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final historyState = ref.watch(recentlySavedProvider);
    final items = historyState.items;

    if (items.isEmpty) {
      return const SizedBox.shrink(); // Hide if history is empty
    }

    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final fgSub = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;

    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENTLY SAVED',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fgSub,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${items.length} items',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fgSub.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: NoSusTheme.s16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              height: 24,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final isUploading = item.status == 'uploading';
              final isFailed = item.status == 'failed';
              final isCompleted = item.status == 'completed';

              final uploadState = ref.watch(uploadProvider);
              final double progress = (historyState.activeUploadId == item.id)
                  ? uploadState.progress
                  : 0.0;

              return InkWell(
                onTap: isCompleted
                    ? () => ref
                          .read(recentlySavedProvider.notifier)
                          .navigateToItem(item, context, ref)
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _getTypeColor(
                                item.type,
                                isDark,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getTypeIcon(item.type),
                              color: _getTypeColor(item.type, isDark),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: fg,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Saved to ${item.destinationName} · ${_formatTimeAgo(item.timestamp)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: fgSub,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isCompleted)
                            Icon(
                              Icons.check_circle_outline,
                              color: isDark
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF059669),
                              size: 18,
                            ),
                          if (isFailed)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton.icon(
                                  onPressed: () => ref
                                      .read(recentlySavedProvider.notifier)
                                      .retryUpload(item.id, ref),
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text(
                                    'RETRY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: isDark
                                        ? Colors.amber[300]
                                        : Colors.amber[800],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => ref
                                      .read(recentlySavedProvider.notifier)
                                      .removeItem(item.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  style: IconButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.red[300]
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          if (isUploading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (isUploading) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progress > 0 ? progress : null,
                                  minHeight: 3,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    fgSub,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: fgSub,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BurnNoteTeaserCard extends StatelessWidget {
  const _BurnNoteTeaserCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(NoSusTheme.r16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const BurnNoteCreatorScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: NoSusTheme.cardDecoration(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                color: Colors.orangeAccent.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.local_fire_department_outlined, color: Colors.orangeAccent, size: 22),
            ),
            const SizedBox(width: NoSusTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Burn Notes',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Zero-knowledge encrypted self-destructing secrets.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.54),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: fg.withValues(alpha: 0.45),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
