import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../../components/content_report_sheet.dart';
import '../../../config/go_config.dart';
import '../../../core/crypto/device_keys.dart';
import '../../../theme.dart';
import '../drive_saved_store.dart';
import '../google_drive_access.dart';
import 'drop_manifest.dart';
import 'drop_repository.dart';

/// Files people sent to your address. Each one is opened on this phone
/// with this phone's key; nothing goes to Drive until you accept.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _Opened {
  final DropManifest? manifest;
  final String? problem;
  const _Opened({this.manifest, this.problem});
}

class _InboxScreenState extends State<InboxScreen> {
  final _repo = DropRepository();
  final _http = http.Client();
  late final DriveSavedStore _drive = DriveSavedStore(
    client: _http,
    token: () => GoogleDriveAccess.instance.accessToken(),
  );

  StreamSubscription<List<DropItem>>? _sub;
  List<DropItem> _drops = const [];
  String? _keyId;
  String? _banner;
  bool _loading = true;
  final Map<String, _Opened> _opened = {};
  final Map<String, Uint8List> _plain = {};
  final Set<String> _busy = {};
  final Set<String> _saved = {};

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _sub?.cancel();
    _http.close();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _keyId = await DeviceKeys.instance.ensureRegistered();
    } catch (_) {
      _keyId = null;
    }
    if (_keyId == null && mounted) {
      setState(() => _banner = 'This phone’s key isn’t set up, so it can’t open drops.');
    }
    _sub = _repo.watchInbox().listen(
      (drops) {
        if (!mounted) return;
        setState(() {
          _drops = drops;
          _loading = false;
        });
        unawaited(_openNew(drops));
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _loading = false;
            _banner = 'Inbox isn’t updating. Pull down to retry.';
          });
        }
      },
    );
  }

  Future<void> _openNew(List<DropItem> drops) async {
    final keyId = _keyId;
    if (keyId == null) return;
    final fresh = [for (final d in drops) if (!_opened.containsKey(d.id)) d.id];
    if (fresh.isEmpty) return;
    Map<String, String> boxes;
    try {
      boxes = await _repo.envelopes(fresh, keyId);
    } catch (_) {
      return;
    }
    for (final id in fresh) {
      final box = boxes[id];
      _Opened opened;
      if (box == null) {
        opened = const _Opened(problem: 'Sealed to another of your devices. Open it there.');
      } else {
        try {
          opened = _Opened(manifest: await DropRepository.openManifest(id, box));
        } catch (_) {
          opened = const _Opened(problem: 'Couldn’t open this on this phone.');
        }
      }
      _opened[id] = opened;
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _sub?.cancel();
    _opened.clear();
    setState(() {
      _banner = null;
      _loading = true;
    });
    await _start();
  }

  Future<Uint8List> _bytes(DropItem drop, DropManifest manifest) async {
    final cached = _plain[drop.id];
    if (cached != null) return cached;
    final bytes = await _repo.fetchFile(drop.id, manifest);
    _plain[drop.id] = bytes;
    return bytes;
  }

  Future<void> _run(String id, Future<void> Function() task) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await task();
    } on DropFailure catch (e) {
      _toast(e.message);
    } on DriveFailure catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _preview(DropItem drop, DropManifest manifest) =>
      _run(drop.id, () async {
        await _bytes(drop, manifest);
        if (mounted) setState(() {});
      });

  Future<void> _accept(DropItem drop, DropManifest manifest) => _run(drop.id, () async {
        await _repo.accept(drop.id);
        final bytes = await _bytes(drop, manifest);
        if (!GoConfig.isConfigured) {
          // No Drive in this build. Hand the file to the share sheet instead.
          await SharePlus.instance.share(ShareParams(
            files: [XFile.fromData(bytes, name: manifest.safeName, mimeType: manifest.safeMime)],
            fileNameOverrides: [manifest.safeName],
          ));
          if (mounted) setState(() => _saved.add(drop.id));
          return;
        }
        try {
          await GoogleDriveAccess.instance.accessToken();
        } on DriveFailure {
          if (await GoogleDriveAccess.instance.connect() == null) {
            throw const DriveFailure('config', 'Connect Google Drive first.');
          }
        }
        final inbox = await _drive.inboxFolder();
        await _drive.putFile(
          savedFolderId: inbox!,
          nosusId: drop.id,
          name: manifest.safeName,
          mime: manifest.safeMime,
          bytes: bytes,
          src: 'drop',
        );
        if (!mounted) return;
        setState(() => _saved.add(drop.id));
        _toast('Saved to Drive · NO SUS/Inbox');
      });

  Future<void> _decline(DropItem drop) => _run(drop.id, () async {
        await _repo.decline(drop.id);
        _forget(drop.id);
      });

  Future<void> _block(DropItem drop) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block this sender?'),
        content: const Text(
          'Drops from the network this came from won’t reach your door. This file is declined. '
          'Networks are shared and change, so this is a speed bump, not a guarantee.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Block')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(drop.id, () async {
      await _repo.block(drop.id);
      _forget(drop.id);
    });
  }

  void _forget(String id) {
    _plain.remove(id);
    if (!mounted) return;
    setState(() => _drops = [for (final d in _drops) if (d.id != id) d]);
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _left(DateTime expires) {
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return 'Deleting soon';
    if (left.inHours >= 1) return 'Deleted in ${left.inHours} h unless you accept';
    return 'Deleted in ${left.inMinutes + 1} min';
  }

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_banner != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_banner!, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (!_loading && _drops.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(
                  'Nothing waiting. Files people send to your address show up here first.',
                  style: TextStyle(color: fg, fontSize: 15),
                ),
              ),
            for (final drop in _drops) _card(drop, fg),
          ],
        ),
      ),
    );
  }

  Widget _card(DropItem drop, Color fg) {
    final subtle = fg.withValues(alpha: 0.62);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opened = _opened[drop.id];
    final manifest = opened?.manifest;
    final busy = _busy.contains(drop.id);
    final plain = _plain[drop.id];
    final saved = _saved.contains(drop.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? NoSusTheme.dCard : NoSusTheme.lCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (manifest == null)
            Text(opened?.problem ?? 'Opening…', style: TextStyle(color: fg, fontSize: 15))
          else ...[
            Text('From ${manifest.from}', style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700)),
            if (manifest.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(manifest.note, style: TextStyle(color: fg, fontSize: 15, height: 1.4)),
            ],
            const SizedBox(height: 6),
            Text('${manifest.safeName} · ${_size(manifest.size)}', style: TextStyle(color: fg, fontSize: 14)),
            Text(
              'Name and note were written by the sender; we can’t check who they are.',
              style: TextStyle(color: subtle, fontSize: 12),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            saved
                ? 'Saved. The encrypted copy on our server is deleted within an hour.'
                : drop.state == 'accepted'
                    ? 'Accepted · ${_left(drop.expiresAt)}'
                    : _left(drop.expiresAt),
            style: TextStyle(color: subtle, fontSize: 12),
          ),
          if (manifest != null && manifest.looksLikeImage) ...[
            const SizedBox(height: 12),
            if (plain != null)
              _BlurredPreview(bytes: plain, label: manifest.safeName)
            else
              OutlinedButton.icon(
                onPressed: busy ? null : () => _preview(drop, manifest),
                icon: const Icon(Icons.blur_on),
                label: const Text('Preview (blurred)'),
              ),
          ],
          const SizedBox(height: 12),
          if (busy) const LinearProgressIndicator(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (manifest != null && !saved)
                FilledButton(
                  onPressed: busy ? null : () => _accept(drop, manifest),
                  child: Text(GoConfig.isConfigured ? 'Accept to Drive' : 'Accept'),
                ),
              OutlinedButton(onPressed: busy ? null : () => _decline(drop), child: Text(saved ? 'Remove' : 'Decline')),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'block') unawaited(_block(drop));
                  if (value == 'report') {
                    unawaited(showContentReportSheet(
                      context,
                      targetKind: 'other',
                      targetId: 'drop:${drop.id}',
                      headline: 'Report this drop',
                    ));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'block', child: Text('Block sender')),
                  PopupMenuItem(value: 'report', child: Text('Report')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Blurred until pressed and held. Decoding happens only after the owner
/// asks for a preview.
class _BlurredPreview extends StatefulWidget {
  final Uint8List bytes;
  final String label;
  const _BlurredPreview({required this.bytes, required this.label});

  @override
  State<_BlurredPreview> createState() => _BlurredPreviewState();
}

class _BlurredPreviewState extends State<_BlurredPreview> {
  bool _clear = false;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: _clear ? 'Preview of ${widget.label}' : 'Blurred preview. Press and hold to see it.',
          image: true,
          child: GestureDetector(
            onLongPressStart: (_) {
              HapticFeedback.selectionClick();
              setState(() => _clear = true);
            },
            onLongPressEnd: (_) => setState(() => _clear = false),
            onLongPressCancel: () => setState(() => _clear = false),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ImageFiltered(
                  enabled: !_clear,
                  imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('No preview for this file.', style: TextStyle(color: fg)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('Press and hold to unblur', style: TextStyle(color: fg.withValues(alpha: 0.62), fontSize: 12)),
      ],
    );
  }
}
