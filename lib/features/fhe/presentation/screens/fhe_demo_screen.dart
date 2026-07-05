import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme.dart';
import '../providers/fhe_provider.dart';

class FheDemoScreen extends ConsumerWidget {
  const FheDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fheDemoProvider);
    final notifier = ref.read(fheDemoProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = fg.withValues(alpha: 0.58);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('Compare Research', style: theme.textTheme.titleMedium),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _MissionBand(fg: fg, subtle: subtle),
            const SizedBox(height: 16),
            _PerspectiveStrip(
              selectedId: state.selectedPerspectiveId,
              onSelected: notifier.selectPerspective,
            ),
            const SizedBox(height: 16),
            _SignalPanel(
              state: state,
              onRun: state.isLoading
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      notifier.executeConfidentialDiscovery();
                    },
            ),
            if (state.inputDocuments.isNotEmpty) ...[
              const SizedBox(height: 16),
              _InputDocumentsPanel(documents: state.inputDocuments),
            ],
            const SizedBox(height: 16),
            _InsightList(state: state),
            if (state.answer != null) ...[
              const SizedBox(height: 16),
              _AnswerReceipt(state: state),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              _ErrorPanel(message: state.error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MissionBand extends StatelessWidget {
  final Color fg;
  final Color subtle;

  const _MissionBand({required this.fg, required this.subtle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: fg, size: 19),
              const SizedBox(width: 10),
              Text(
                'PRIVATE RESEARCH COMPARISON',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: subtle,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Three organizations compare sensitive knowledge and receive one shared insight without revealing their underlying documents.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }
}

class _PerspectiveStrip extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelected;

  const _PerspectiveStrip({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: FheDemoNotifier.participants.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final participant = FheDemoNotifier.participants[index];
          final selected = participant.id == selectedId;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onSelected(participant.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 190,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? fg.withValues(alpha: 0.08)
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? fg : fg.withValues(alpha: 0.12),
                  width: selected ? 1.2 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected ? Icons.visibility : Icons.visibility_outlined,
                    size: 18,
                    color: fg,
                  ),
                  const Spacer(),
                  Text(
                    participant.organization,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${participant.role} · ${participant.clearanceLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: 0.52),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  final FheDemoState state;
  final VoidCallback? onRun;

  const _SignalPanel({required this.state, required this.onRun});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISCOVERY QUESTION',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg.withValues(alpha: 0.46),
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Where do our private research documents overlap, contradict, and create a joint opportunity?',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.enhanced_encryption_outlined, color: fg, size: 22),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRun,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(state.isLoading ? 'COMPARING' : 'COMPARE RESEARCH'),
              style: ElevatedButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (state.statusText != null) ...[
            const SizedBox(height: 14),
            Text(
              state.statusText!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg.withValues(alpha: 0.58),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InputDocumentsPanel extends StatelessWidget {
  final List<ResearchInputDocument> documents;

  const _InputDocumentsPanel({required this.documents});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INPUT DOCUMENTS',
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg.withValues(alpha: 0.46),
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...documents.map(
            (doc) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    doc.signalFromDocument
                        ? Icons.description_outlined
                        : Icons.upload_file_outlined,
                    size: 17,
                    color: fg.withValues(
                      alpha: doc.signalFromDocument ? 0.85 : 0.4,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.organization,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          doc.signalFromDocument
                              ? '${doc.fileName} · signal extracted from document'
                              : doc.fileName != null
                                  ? '${doc.fileName} · text unavailable, manual demo vector'
                                  : 'Not uploaded · manual demo vector',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _InsightList extends StatelessWidget {
  final FheDemoState state;

  const _InsightList({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.insights.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENCRYPTED OVERLAP SCORES',
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg.withValues(alpha: 0.46),
              fontSize: 10,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...state.insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: fg.withValues(alpha: 0.18)),
                      ),
                      child: Center(
                        child: Text(
                          '${insight.score}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.participant.organization,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          insight.encryptedScorePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: fg.withValues(alpha: 0.46),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _AnswerReceipt extends StatelessWidget {
  final FheDemoState state;

  const _AnswerReceipt({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: NoSusTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_outlined, color: fg, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI SUMMARY',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg.withValues(alpha: 0.5),
                  fontSize: 10,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                state.confidence ?? '',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (state.aiModeLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              state.aiModeLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: fg.withValues(alpha: 0.45),
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            state.answer!,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          _BulletSection(title: 'SHARED FINDINGS', items: state.sharedFindings),
          _BulletSection(title: 'CONTRADICTIONS', items: state.contradictions),
          _BulletSection(
            title: 'COLLABORATION OPPORTUNITIES',
            items: state.opportunities,
          ),
          const SizedBox(height: 14),
          ...state.permissionSummary.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 15, color: fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 22),
          Text(
            '${state.receiptId}  |  ${state.encryptedReceiptPreview}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: fg.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }
}

class _BulletSection extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg.withValues(alpha: 0.48),
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 7),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.68),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.redAccent,
          fontSize: 12,
        ),
      ),
    );
  }
}
