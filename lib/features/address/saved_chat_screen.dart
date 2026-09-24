import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/go_config.dart';
import '../config/presentation/providers/config_provider.dart';
import 'drop/inbox_screen.dart';
import 'drive_saved_store.dart';
import 'go_widgets.dart';
import 'google_drive_access.dart';

/// Something the share sheet handed us, already read into memory so the
/// dialog can delete its temp file.
class SavedPending {
  final String? text;
  final Uint8List? bytes;
  final String? name;
  final String? mime;

  const SavedPending.text(this.text)
      : bytes = null,
        name = null,
        mime = null;

  const SavedPending.file(this.bytes, this.name, this.mime) : text = null;
}

class SavedChatScreen extends ConsumerStatefulWidget {
  final SavedPending? pending;

  const SavedChatScreen({super.key, this.pending});

  @override
  ConsumerState<SavedChatScreen> createState() => _SavedChatScreenState();
}

class _SavedChatScreenState extends ConsumerState<SavedChatScreen> {
  final _text = TextEditingController();
  final _client = http.Client();
  late final DriveSavedStore _store = DriveSavedStore(
    client: _client,
    token: () => GoogleDriveAccess.instance.accessToken(),
  );
  final _uuid = const Uuid();

  DriveFolders? _folders;
  String? _inbox;
  List<SavedItem> _items = const [];
  String? _email;
  String? _banner;
  bool _busy = false;
  bool _configured = GoConfig.isConfigured;
  bool _atePending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _text.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _banner = null;
    });
    try {
      _email = await GoogleDriveAccess.instance.savedEmail();
      if (!GoConfig.isConfigured) {
        setState(() {
          _configured = false;
          _busy = false;
        });
        return;
      }
      _folders = await _store.ensureFolders();
      _inbox = await _store.inboxFolder(create: false);
      final items = await _store.listTimeline(_folders!, inboxFolderId: _inbox);
      if (!mounted) return;
      setState(() {
        _items = items;
        _busy = false;
      });
      final pending = widget.pending;
      if (pending != null && _folders != null && !_atePending) {
        _atePending = true;
        await _savePending(pending);
      }
    } on DriveFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _banner = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _banner = 'Couldn’t open Drive.';
        _busy = false;
      });
    }
  }

  Future<void> _savePending(SavedPending pending) async {
    if (pending.text != null) {
      await _saveText(pending.text!);
    } else if (pending.bytes != null) {
      await _saveFile(pending.bytes!, pending.name ?? 'file', pending.mime ?? 'application/octet-stream');
    }
  }

  Future<void> _connect() async {
    try {
      final email = await GoogleDriveAccess.instance.connect();
      if (!mounted) return;
      if (email == null) {
        setState(() => _banner = 'Build the app with GO_WEB_CLIENT_ID to connect Drive.');
        return;
      }
      setState(() => _email = email);
      await _load();
    } on DriveFailure catch (e) {
      if (mounted) setState(() => _banner = e.message);
    }
  }

  Future<void> _saveText(String text) async {
    final folders = _folders;
    final trimmed = text.trim();
    if (folders == null || trimmed.isEmpty) return;
    setState(() => _banner = 'Saving…');
    try {
      await _store.putMessage(
        messagesFolderId: folders.messages,
        nosusId: _uuid.v4(),
        text: trimmed,
        src: 'phone',
      );
      _text.clear();
      await _reloadQuiet();
      if (mounted) setState(() => _banner = null);
    } on DriveFailure catch (e) {
      if (mounted) setState(() => _banner = '${e.message} · Retry');
    }
  }

  Future<void> _saveFile(Uint8List bytes, String name, String mime) async {
    final folders = _folders;
    if (folders == null) return;
    setState(() => _banner = 'Saving…');
    try {
      await _store.putFile(
        savedFolderId: folders.saved,
        nosusId: _uuid.v4(),
        name: name,
        mime: mime,
        bytes: bytes,
        src: 'phone',
      );
      await _reloadQuiet();
      if (mounted) setState(() => _banner = null);
    } on DriveFailure catch (e) {
      if (mounted) setState(() => _banner = e.code == 'full' ? 'Drive is full.' : '${e.message} · Retry');
    }
  }

  Future<void> _reloadQuiet() async {
    final folders = _folders;
    if (folders == null) return;
    final items = await _store.listTimeline(folders, inboxFolderId: _inbox);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    await _saveFile(bytes, file.name, _mime(file.extension));
  }

  String _mime(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  void _computerHelp() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Open on a computer', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('On that computer, open nosus.foo/go and scan the code with this phone. Your Google account stays here.'),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(const ClipboardData(text: GoConfig.deskUrl));
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Copy nosus.foo/go'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.62);
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved'),
            Text('Saved to your Google Drive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (ref.watch(featureFlagProvider('nosus_drop_enabled')))
            IconButton(
              tooltip: 'Inbox',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InboxScreen()),
              ),
              icon: const Icon(Icons.inbox_outlined),
            ),
          IconButton(
            tooltip: 'Open on computer',
            onPressed: _computerHelp,
            icon: const Icon(Icons.computer),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_email != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_email!, style: TextStyle(color: subtle, fontSize: 13)),
              ),
            ),
          if (_banner != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_banner!, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: !_configured
                ? const Center(child: Text('Drive connects once this build has a Google client id.'))
                : _folders == null
                    ? Center(
                        child: _busy
                            ? const CircularProgressIndicator()
                            : FilledButton(onPressed: _connect, child: const Text('Connect Google Drive')),
                      )
                    : RefreshIndicator(
                        onRefresh: _reloadQuiet,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 48),
                                child: Text('Nothing saved yet. Send a note, a link, or a file.'),
                              ),
                            for (final item in _items)
                              SavedLine(
                                text: item.isMessage ? (item.text ?? item.name) : '${item.name} · ${_size(item.size)}',
                                detail: switch (item.src) {
                                  'computer' => 'From computer',
                                  'drop' => 'From your address',
                                  _ => 'From phone',
                                },
                                status: 'Saved to Drive',
                              ),
                          ],
                        ),
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach',
                    onPressed: _folders == null ? null : _attach,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Note or link',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _saveText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _folders == null ? null : () => _saveText(_text.text),
                      child: const Text('Send'),
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

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
