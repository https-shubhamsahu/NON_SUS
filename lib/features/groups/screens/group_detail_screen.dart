import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/models/study_group.dart';
import '../models/group_file.dart';
import '../providers/groups_provider.dart';
import '../widgets/file_card.dart';
import '../widgets/member_avatar_stack.dart';
import '../widgets/security_badge.dart';
import '../widgets/upload_modal.dart';
import '../widgets/empty_states.dart';
import '../data/mock_groups_data.dart';
import '../../../theme.dart';
import '../../../components/spyglass_viewer.dart';
import '../../../services/zero_trust_gateway.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../audit/providers/audit_provider.dart';

/// Full-screen group detail page with tabbed content:
/// Files | Notes | Members | Activity
class GroupDetailScreen extends ConsumerStatefulWidget {
  final StudyGroup group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openUploadModal() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadModal(groupId: widget.group.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? NoSusTheme.dBackground : NoSusTheme.lBackground;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark
        ? NoSusTheme.dTextSecondary
        : NoSusTheme.lTextSecondary;
    final cardBg = isDark ? NoSusTheme.dCard : NoSusTheme.lCard;

    final groupsAsync = ref.watch(groupsProvider);
    final group = groupsAsync.maybeWhen(
      data: (list) {
        try {
          return list.firstWhere((g) => g.id == widget.group.id);
        } catch (_) {
          return widget.group;
        }
      },
      orElse: () => widget.group,
    );

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, _) => [
          // ── Sliver app bar ──────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: bg,
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: fg, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Upload FAB in app bar
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: _openUploadModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'UPLOAD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                padding: const EdgeInsets.fromLTRB(24, 90, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SecurityBadge(
                      level: group.securityLevel,
                    ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(height: 12),
                    Text(
                          group.name,
                          style: TextStyle(
                            color: fg,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 60.ms)
                        .slideY(begin: 0.03, end: 0),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        MemberAvatarStack(
                          members: group.members,
                          maxVisible: 4,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${group.memberCount} members  ·  ${group.fileCount} files',
                          style: TextStyle(fontSize: 12, color: subtle),
                        ),
                      ],
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),
            ),
            // Tab bar pinned at bottom of sliver
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(44),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: fg.withValues(alpha: 0.08),
                      width: 0.5,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: fg,
                  unselectedLabelColor: subtle,
                  indicatorColor: fg,
                  indicatorWeight: 1.5,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: 'FILES'),
                    Tab(text: 'NOTES'),
                    Tab(text: 'MEMBERS'),
                    Tab(text: 'ACTIVITY'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _FilesTab(group: group, onUpload: _openUploadModal),
            _NotesTab(
              group: group,
              fg: fg,
              subtle: subtle,
              cardBg: cardBg,
            ),
            _MembersTab(members: group.members, fg: fg, subtle: subtle),
            _ActivityTab(groupId: group.id, fg: fg, subtle: subtle),
          ],
        ),
      ),
    );
  }
}

// ─── Files tab ────────────────────────────────────────────────────────────────

class _FilesTab extends ConsumerWidget {
  final StudyGroup group;
  final VoidCallback onUpload;

  const _FilesTab({required this.group, required this.onUpload});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(groupFilesProvider);

    return filesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (e, _) => Center(
        child: Text(
          'Failed to load files',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
      data: (filesMap) {
        final allFiles = filesMap[group.id] ?? [];
        final files = allFiles.where((f) => f.type != FileType.markdown).toList();
        
        return files.isEmpty
            ? FilesEmptyState(onUpload: onUpload)
            : ListView.separated(
                padding: const EdgeInsets.all(NoSusTheme.s24),
                physics: const BouncingScrollPhysics(),
                itemCount: files.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: NoSusTheme.s12),
                itemBuilder: (context, i) {
                  final file = files[i];
                  return FileCard(
                    file: file,
                    animationIndex: i,
                    onDelete: () => ref
                        .read(groupFilesProvider.notifier)
                        .removeFile(group.id, file.id),
                    onPin: () => ref
                        .read(groupFilesProvider.notifier)
                        .togglePin(group.id, file.id),
                    onOpen: () => _evaluateAndOpenFile(
                      context: context,
                      ref: ref,
                      file: file,
                      group: group,
                    ),
                  );
                },
              );
      },
    );
  }
}

// ─── Notes tab ────────────────────────────────────────────────────────────────

class _NotesTab extends ConsumerWidget {
  final StudyGroup group;
  final Color fg;
  final Color subtle;
  final Color cardBg;

  const _NotesTab({
    required this.group,
    required this.fg,
    required this.subtle,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filesAsync = ref.watch(groupFilesProvider);

    return filesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (e, _) => Center(
        child: Text(
          'Failed to load notes',
          style: TextStyle(
            color: subtle,
          ),
        ),
      ),
      data: (filesMap) {
        final allFiles = filesMap[group.id] ?? [];
        final notes = allFiles.where((f) => f.type == FileType.markdown).toList();

        if (notes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_alt_outlined, size: 48, color: subtle),
                const SizedBox(height: 16),
                Text(
                  'NO SECURE NOTES YET',
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Auto-generated group notes will appear here shortly.',
                  style: TextStyle(color: subtle, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(NoSusTheme.s24),
          physics: const BouncingScrollPhysics(),
          itemCount: notes.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: NoSusTheme.s12),
          itemBuilder: (context, i) {
            final note = notes[i];
            return _PinnedNoteCard(
              note: note,
              fg: fg,
              subtle: subtle,
              cardBg: cardBg,
              index: i,
              onOpen: () => _evaluateAndOpenFile(
                context: context,
                ref: ref,
                file: note,
                group: group,
              ),
              onDelete: () => ref
                  .read(groupFilesProvider.notifier)
                  .removeFile(group.id, note.id),
            );
          },
        );
      },
    );
  }
}

class _PinnedNoteCard extends StatelessWidget {
  final GroupFile note;
  final Color fg;
  final Color subtle;
  final Color cardBg;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _PinnedNoteCard({
    required this.note,
    required this.fg,
    required this.subtle,
    required this.cardBg,
    required this.index,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(NoSusTheme.s16),
        decoration: NoSusTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.push_pin, size: 12, color: subtle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.name,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: subtle.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to decrypt and read secure note content...',
              style: TextStyle(
                color: fg.withValues(alpha: 0.4),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Uploaded by ${note.uploadedByName}  ·  ${note.uploadedAtLabel}',
              style: TextStyle(
                color: subtle,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    )
    .animate(delay: (index * 80).ms)
    .fadeIn(duration: 250.ms)
    .slideY(begin: 0.03, end: 0);
  }
}

// ─── Zero-Trust Gateway File Open Helper ──────────────────────────────────────

Future<void> _evaluateAndOpenFile({
  required BuildContext context,
  required WidgetRef ref,
  required GroupFile file,
  required StudyGroup group,
}) async {
  // 1. Show dynamic security policy evaluation loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      return Theme(
        data: Theme.of(dialogContext),
        child: Dialog(
          backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? const Color(0x33FFFFFF) : const Color(0xFF1A1A1A),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 32.0,
              horizontal: 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'EVALUATING SECURITY POLICY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: isDark
                        ? NoSusTheme.dText.withValues(
                            alpha: 0.5,
                          )
                        : NoSusTheme.lText.withValues(
                            alpha: 0.5,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Requesting enclave access...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? NoSusTheme.dText.withValues(
                            alpha: 0.7,
                          )
                        : NoSusTheme.lText.withValues(
                            alpha: 0.7,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  // 2. Dispatch simulated HTTPS check to ZeroTrustGateway
  final currentUser = ref.read(authStateProvider).value;
  final userId = currentUser?.id ?? 'me';
  final response = await ZeroTrustGateway.requestDocument(
    userId,
    file.id,
  );

  // 3. Pop the dialog
  if (context.mounted) {
    Navigator.of(context).pop();
  }

  // 4. Evaluate access policy response
  if (response.isSuccess) {
    // Log successful secure document access
    ref.read(auditLogsProvider.notifier).addLog(
          "Document Access Authorized: ${file.name}",
          "SUCCESS",
        );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpyglassViewer(
            fileId: file.id,
            documentTitle: file.name,
            documentCategory: file.type.label,
          ),
        ),
      );
    }
  } else {
    // Log blocked unauthorized document access attempt
    ref.read(auditLogsProvider.notifier).addLog(
          "Unauthorized Access Blocked: Enclave Group ${group.name}",
          "SECURITY",
        );

    // Show premium monochrome "Access Denied" explanation dialog
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          return Theme(
            data: Theme.of(dialogContext),
            child: Dialog(
              backgroundColor: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0xFF1A1A1A),
                  width: 1.2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.gpp_bad_outlined,
                      color: Colors.amber,
                      size: 44,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'ACCESS DENIED',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: isDark ? NoSusTheme.dText : NoSusTheme.lText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      response.errorMessage ??
                          'You do not have permission to view this secure document.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? NoSusTheme.dText.withValues(
                                alpha: 0.6,
                              )
                            : NoSusTheme.lText.withValues(
                                alpha: 0.6,
                              ),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        decoration: NoSusTheme.buttonDecoration(
                          dialogContext,
                          radius: 10,
                        ),
                        child: Text(
                          'DISMISS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: isDark ? NoSusTheme.dText : NoSusTheme.lText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }
  }
}

// ─── Members tab ──────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final List<GroupMember> members;
  final Color fg;
  final Color subtle;

  const _MembersTab({
    required this.members,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return _buildList(context, members);
  }

  Widget _buildList(BuildContext context, List<GroupMember> list) {
    return ListView.separated(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: NoSusTheme.s12),
      itemBuilder: (context, i) {
        final member = list[i];
        return Container(
              padding: const EdgeInsets.all(NoSusTheme.s16),
              decoration: NoSusTheme.cardDecoration(context),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: fg.withValues(alpha: 0.15),
                        width: 0.75,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        member.initials,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          member.isAdmin ? 'Admin' : 'Member',
                          style: TextStyle(color: subtle, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (member.isAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: fg.withValues(alpha: 0.2),
                          width: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 9,
                          color: subtle,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
            )
            .animate(delay: (i * 60).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.03, end: 0);
      },
    );
  }
}

// ─── Activity tab ─────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String groupId;
  final Color fg;
  final Color subtle;

  const _ActivityTab({
    required this.groupId,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogs = ref.watch(auditLogsProvider);

    // If there are no real audit logs yet, fall back to mock group activity
    if (auditLogs.isEmpty) {
      final activities = MockGroupsData.activityForGroup(groupId);
      return ListView.builder(
        padding: const EdgeInsets.all(NoSusTheme.s24),
        physics: const BouncingScrollPhysics(),
        itemCount: activities.length,
        itemBuilder: (_, i) {
          final item = activities[i];
          final icon = _iconForMock(item['icon']!);
          return Padding(
            padding: const EdgeInsets.only(bottom: NoSusTheme.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fg.withValues(alpha: 0.12),
                      width: 0.75,
                    ),
                  ),
                  child: Icon(icon, size: 14, color: subtle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['text']!,
                        style: TextStyle(color: fg, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['time']!,
                        style: TextStyle(color: subtle, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate(delay: (i * 60).ms).fadeIn(duration: 250.ms),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(NoSusTheme.s24),
      physics: const BouncingScrollPhysics(),
      itemCount: auditLogs.length,
      itemBuilder: (_, i) {
        final item = auditLogs[i];
        final event = item['event'] ?? '';
        final time = item['time'] ?? '';
        final status = item['status'] ?? '';
        final icon = _iconForStatus(status);

        return Padding(
          padding: const EdgeInsets.only(bottom: NoSusTheme.s16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: fg.withValues(alpha: 0.12),
                    width: 0.75,
                  ),
                ),
                child: Icon(icon, size: 14, color: subtle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event,
                      style: TextStyle(color: fg, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(color: subtle, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ).animate(delay: (i * 60).ms).fadeIn(duration: 250.ms),
        );
      },
    );
  }

  IconData _iconForMock(String type) => switch (type) {
    'upload' => Icons.upload_file_outlined,
    'member' => Icons.person_add_outlined,
    'pin' => Icons.push_pin_outlined,
    'key' => Icons.key_outlined,
    _ => Icons.info_outline,
  };

  IconData _iconForStatus(String status) => switch (status.toUpperCase()) {
    'SUCCESS' => Icons.check_circle_outline,
    'SECURITY' => Icons.gpp_maybe_outlined,
    'INFO' => Icons.info_outline,
    _ => Icons.info_outline,
  };
}
