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
import '../../../fhe/presentation/screens/fhe_demo_screen.dart';
import '../../../fhe/presentation/providers/fhe_provider.dart';

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
  final TextEditingController _askAiController = TextEditingController();

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
    _askAiController.dispose();
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

          _AskAiBox(
            controller: _askAiController,
          ).animate().fadeIn(duration: 340.ms).slideY(begin: 0.05, end: 0),
          const SizedBox(height: NoSusTheme.s16),

          const _ConfidentialDiscoveryCard()
              .animate()
              .fadeIn(duration: 360.ms)
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

class _AskAiBox extends ConsumerWidget {
  final TextEditingController controller;

  const _AskAiBox({required this.controller});

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final question = controller.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type a question for Ask AI first.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(fheDemoProvider.notifier)
        .executeConfidentialDiscovery(question: question);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurface;
    final aiState = ref.watch(fheDemoProvider);
    final answer = aiState.answer;

    return Container(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fg.withValues(alpha: 0.16)),
                  color: fg.withValues(alpha: 0.04),
                ),
                child: Icon(Icons.auto_awesome_outlined, color: fg, size: 20),
              ),
              const SizedBox(width: NoSusTheme.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ASK AI',
                      style: theme.textTheme.labelLarge?.copyWith(
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Privacy-safe answers from derived findings, not raw documents.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: NoSusTheme.s16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fg.withValues(alpha: 0.12)),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.025),
            ),
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(context, ref),
              cursorColor: fg,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg.withValues(alpha: 0.88),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Ask: Which group matches my research question best?',
                hintStyle: TextStyle(color: fg.withValues(alpha: 0.35)),
              ),
            ),
          ),
          const SizedBox(height: NoSusTheme.s12),
          Row(
            children: [
              Expanded(
                child: Text(
                  aiState.isLoading
                      ? (aiState.statusText ?? 'Running confidential AI...')
                      : aiState.questionText ?? 'Ready for a sealed question.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: NoSusTheme.s12),
              FilledButton.icon(
                onPressed: aiState.isLoading
                    ? null
                    : () => _submit(context, ref),
                icon: aiState.isLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(aiState.isLoading ? 'ASKING' : 'ASK'),
                style: FilledButton.styleFrom(
                  backgroundColor: fg,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          if (aiState.error != null) ...[
            const SizedBox(height: NoSusTheme.s12),
            Text(
              aiState.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.redAccent,
              ),
            ),
          ],
          if (answer != null && answer.isNotEmpty) ...[
            const SizedBox(height: NoSusTheme.s16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(NoSusTheme.s16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NoSusTheme.r16),
                border: Border.all(color: fg.withValues(alpha: 0.1)),
                color: fg.withValues(alpha: 0.04),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aiState.aiModeLabel ?? 'Restricted AI answer',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg.withValues(alpha: 0.55),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s8),
                  Text(
                    answer,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: fg.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: NoSusTheme.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FheDemoScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('FULL BRIEFING'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfidentialDiscoveryCard extends StatelessWidget {
  const _ConfidentialDiscoveryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(NoSusTheme.r16),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FheDemoScreen()));
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
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: fg.withValues(alpha: 0.18)),
              ),
              child: Icon(Icons.hub_outlined, color: fg, size: 22),
            ),
            const SizedBox(width: NoSusTheme.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compare Research',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Hospital Alpha + University Beta + Research Lab Gamma',
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
