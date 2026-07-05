import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/share_providers.dart';

/// Creates a share link for [fileId] and shows it in a copyable dialog.
///
/// The link opens for ANYONE — no NO SUS account required. Protection on that
/// anonymous view is watermark + blur-until-touch + view logging, never a
/// hard screenshot block (that's only possible inside the installed app).
Future<void> showShareLinkDialog(
  BuildContext context,
  WidgetRef ref,
  String fileId,
) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ShareLinkDialog(fileId: fileId),
  );
}

class _ShareLinkDialog extends ConsumerStatefulWidget {
  const _ShareLinkDialog({required this.fileId});
  final String fileId;

  @override
  ConsumerState<_ShareLinkDialog> createState() => _ShareLinkDialogState();
}

class _ShareLinkDialogState extends ConsumerState<_ShareLinkDialog> {
  String? _url;
  String? _error;

  @override
  void initState() {
    super.initState();
    _create();
  }

  Future<void> _create() async {
    try {
      final link =
          await ref.read(shareRepositoryProvider).createShareLink(widget.fileId);
      if (!mounted) return;
      // Uri.base is the origin the web app is currently served from — no
      // hardcoded host, works identically in dev and on the deployed URL.
      setState(() => _url = '${Uri.base.origin}/#/v/${link.token}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          'Could not create a share link. Only the person who uploaded '
          'this file can share it.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      title: const Text('SHARE LINK',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 320,
        child: _error != null
            ? Text(_error!, style: const TextStyle(fontSize: 12))
            : _url == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(_url!,
                            style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Anyone with this link can view the document — no '
                        'account needed. It is watermarked with their email '
                        'and every view is logged.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
        if (_url != null) ...[
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _url!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Link copied'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('COPY', style: TextStyle(fontSize: 11)),
          ),
          FilledButton(
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: 'Here is a secure document link: $_url'),
            ),
            child: const Text('SHARE', style: TextStyle(fontSize: 11)),
          ),
        ],
      ],
    );
  }
}
