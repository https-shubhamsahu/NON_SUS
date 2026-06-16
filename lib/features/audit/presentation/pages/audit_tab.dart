import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../theme.dart';
import '../../providers/audit_provider.dart';

class AuditTab extends ConsumerStatefulWidget {
  const AuditTab({super.key});

  @override
  ConsumerState<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends ConsumerState<AuditTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final auditLogs = ref.watch(auditLogsProvider);

    return Column(
      key: const ValueKey('audit_tab'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SECURITY LEDGER & AUDIT LOGS',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: NoSusTheme.s24),

        // List of audit records
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: NoSusTheme.cardDecoration(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NoSusTheme.r16),
              child: ListView.separated(
                padding: const EdgeInsets.all(NoSusTheme.s24),
                itemCount: auditLogs.length,
                separatorBuilder: (context, index) => Divider(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  height: NoSusTheme.s24,
                ),
                itemBuilder: (context, index) {
                  final log = auditLogs[index];

                  Color statusColor;
                  switch (log['status']) {
                    case 'SUCCESS':
                      statusColor = const Color(0xFF10B981);
                      break;
                    case 'SECURITY':
                      statusColor = Colors.amber;
                      break;
                    default:
                      statusColor = theme.colorScheme.onSurface.withValues(
                        alpha: 0.4,
                      );
                  }

                  return Row(
                    children: [
                      // Status dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: NoSusTheme.s16),
                      // Time
                      Text(
                        log['time'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Courier',
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: NoSusTheme.s24),
                      // Event description
                      Expanded(
                        child: Text(
                          log['event'] ?? '',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ).animate().fadeIn(duration: 300.ms),
        ),
      ],
    );
  }
}
