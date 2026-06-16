import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../theme.dart';
import '../../../groups/models/group_file.dart';
import '../../../groups/providers/groups_provider.dart';
import '../../../../services/secure_db_service.dart';

class VaultTab extends ConsumerStatefulWidget {
  final ValueChanged<String> onRevealRequested;

  const VaultTab({
    super.key,
    required this.onRevealRequested,
  });

  @override
  ConsumerState<VaultTab> createState() => _VaultTabState();
}

class _VaultTabState extends ConsumerState<VaultTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isRotatingKeys = false;
  String? _selectedFileId;

  void _triggerKeyRotation() async {
    if (_isRotatingKeys) return;
    setState(() {
      _isRotatingKeys = true;
    });

    try {
      await SecureDbService.instance.rotateWorkspaceKeys();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.onSurface,
            content: Text(
              'Encryption keys successfully rotated.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              'Key rotation failed: $e',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRotatingKeys = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;

    final filesAsync = ref.watch(groupFilesProvider);
    final allFiles = filesAsync.maybeWhen(
      data: (filesMap) => filesMap.values.expand((x) => x).toList(),
      orElse: () => <GroupFile>[],
    );

    return Column(
      key: const ValueKey('vault_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STUDY VAULT',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            GestureDetector(
              onTap: _triggerKeyRotation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NoSusTheme.s16,
                  vertical: NoSusTheme.s8,
                ),
                decoration: NoSusTheme.buttonDecoration(context),
                child: Row(
                  children: [
                    _isRotatingKeys
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey,
                            ),
                          )
                        : Icon(
                            Icons.sync_lock,
                            size: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                    const SizedBox(width: NoSusTheme.s8),
                    Text(
                      _isRotatingKeys ? 'ROTATING...' : 'ROTATE KEYS',
                      style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: NoSusTheme.s24),

        // List of classified study documents
        Expanded(
          child: allFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_off_outlined,
                        size: 48,
                        color: fg.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO SECURE DOCUMENTS YET',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: fg.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Navigate to the Groups tab to upload secure files.',
                        style: TextStyle(fontSize: 13, color: subtle),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: allFiles.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: NoSusTheme.s16),
                  itemBuilder: (context, index) {
                    final file = allFiles[index];
                    final isSelected = _selectedFileId == file.id;

                    return Container(
                      padding: const EdgeInsets.all(NoSusTheme.s24),
                      decoration: NoSusTheme.cardDecoration(context),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: NoSusTheme.s8,
                                        vertical: 3,
                                      ),
                                      decoration: NoSusTheme.buttonDecoration(
                                        context,
                                        radius: 6,
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.05),
                                      ),
                                      child: Text(
                                        file.type.label,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          fontSize: 9,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: NoSusTheme.s8),
                                    Text(
                                      file.sizeLabel,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: NoSusTheme.s12),
                                Text(
                                  '${file.name}${file.type.extension}',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: NoSusTheme.s4),
                                Text(
                                  'Imported: ${file.uploadedAtLabel}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: NoSusTheme.s24),
                          // Action button to open in Spyglass
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFileId = file.id;
                              });
                              widget.onRevealRequested(file.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: NoSusTheme.s16,
                                vertical: NoSusTheme.s12,
                              ),
                              decoration: NoSusTheme.buttonDecoration(
                                context,
                                radius: 12,
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 16,
                                    color: isSelected
                                        ? theme.colorScheme.surface
                                        : theme.colorScheme.onSurface,
                                  ),
                                  const SizedBox(width: NoSusTheme.s8),
                                  Text(
                                    'REVEAL',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontSize: 11,
                                      color: isSelected
                                          ? theme.colorScheme.surface
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (index * 80).ms).slideY(begin: 0.05, end: 0);
                  },
                ),
        ),
      ],
    );
  }
}
