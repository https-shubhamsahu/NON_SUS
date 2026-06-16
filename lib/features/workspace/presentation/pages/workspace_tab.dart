import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme.dart';
import '../../../../components/study_chart.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../../services/secure_db_service.dart';
import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../../../services/supabase_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../notes/providers/notes_provider.dart';

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
        final content = await SecureDbService.instance.fetchUserNote(user.id);
        if (mounted) {
          ref.read(userNoteProvider.notifier).loadNote(user.id);
          _noteController.text = content.isNotEmpty ? content : AppConstants.defaultNoteContent;
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
    final authState = ref.watch(authStateProvider);
    final userEmail = authState.value?.email ?? 'Student Guest';
    final profileAsync = ref.watch(profileProvider);
    final displayName = profileAsync.maybeWhen(
      data: (p) => p.displayName,
      orElse: () =>
          userEmail.contains('@') ? userEmail.split('@').first : 'Student Guest',
    );
    final isLive = SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable;

    return Column(
      key: const ValueKey('workspace_tab'),
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
                    isLive ? 'Live Encrypted Workspace' : 'Offline Fallback Mode',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),

        const SizedBox(height: NoSusTheme.s16),

        // ── Study Chart + Secure Notepad ──────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 12,
                child: const StudyChart()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),
              ),
              const SizedBox(height: NoSusTheme.s16),
              Expanded(
                flex: 11,
                child: _SecurePad(controller: _noteController)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.05, end: 0),
              ),
            ],
          ),
        ),
      ],
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
                  'ENCRYPTING...',
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
