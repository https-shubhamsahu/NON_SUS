import 'package:flutter/material.dart';

import '../services/content_report_client.dart';
import '../theme.dart';

Future<void> showContentReportSheet(
  BuildContext context, {
  required String targetKind,
  required String targetId,
  String? groupId,
  String? headline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => ContentReportSheet(
      targetKind: targetKind,
      targetId: targetId,
      groupId: groupId,
      headline: headline,
    ),
  );
}

class ContentReportSheet extends StatefulWidget {
  const ContentReportSheet({
    super.key,
    required this.targetKind,
    required this.targetId,
    this.groupId,
    this.headline,
  });

  final String targetKind;
  final String targetId;
  final String? groupId;
  final String? headline;

  @override
  State<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<ContentReportSheet> {
  static const _reasonLabels = <String, String>{
    'spam': 'Spam',
    'harassment': 'Harassment',
    'inappropriate': 'Inappropriate',
    'illegal': 'Illegal activity',
    'other': 'Something else',
  };

  String? _reason;
  bool _sending = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ContentReportClient.instance.submit(
        targetKind: widget.targetKind,
        targetId: widget.targetId,
        groupId: widget.groupId,
        reason: reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report sent. We will review it.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ContentReportDuplicateException {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already reported this today.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send. Check your connection and try again.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: NoSusTheme.s24,
        right: NoSusTheme.s24,
        top: NoSusTheme.s24,
        bottom: MediaQuery.of(context).viewInsets.bottom + NoSusTheme.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'REPORT',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: NoSusTheme.s12),
          Text(
            widget.headline ??
                'Tell us why this should be reviewed. We do not send this to the group.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          const SizedBox(height: NoSusTheme.s16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _reasonLabels.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _reason == entry.key,
                  onSelected: _sending
                      ? null
                      : (selected) {
                          if (selected) setState(() => _reason = entry.key);
                        },
                ),
            ],
          ),
          const SizedBox(height: NoSusTheme.s16),
          TextField(
            controller: _details,
            maxLines: 3,
            maxLength: 500,
            enabled: !_sending,
            decoration: const InputDecoration(
              hintText: 'Optional details. Do not paste secrets or file contents.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: NoSusTheme.s16),
          FilledButton(
            onPressed: _reason == null || _sending ? null : _submit,
            child: Text(
              _sending ? 'SENDING…' : 'SUBMIT REPORT',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
