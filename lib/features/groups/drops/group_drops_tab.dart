import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../components/content_report_sheet.dart';
import '../../../config/go_config.dart';
import '../../../core/crypto/nosus_seal.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../services/supabase_service.dart';
import '../../../theme.dart';
import '../../address/drive_saved_store.dart';
import '../../address/google_drive_access.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/models/study_group.dart';
import '../providers/groups_provider.dart';
import 'group_drive_copy.dart';
import 'group_drop_crypto.dart';
import 'group_drops_providers.dart';
import 'group_drops_repository.dart';
import 'group_keys.dart';

const _encryptionLine =
    'End-to-end encrypted. NO SUS relays messages and deletes them after 30 days; files after 7 days.';
const _fileRetention = Duration(days: 7);
const _setupFailed = 'Couldn’t set up encryption for this chat. Tap to retry.';

enum _Lock { none, noKey, broken }

class _Opened {
  final DropPayload? payload;
  final _Lock lock;
  const _Opened(this.payload) : lock = _Lock.none;
  const _Opened.locked(this.lock) : payload = null;
}

/// The CHAT tab: an end-to-end encrypted feed for one group.
class GroupDropsTab extends ConsumerStatefulWidget {
  final StudyGroup group;

  const GroupDropsTab({super.key, required this.group});

  @override
  ConsumerState<GroupDropsTab> createState() => _GroupDropsTabState();
}

class _GroupDropsTabState extends ConsumerState<GroupDropsTab>
    with AutomaticKeepAliveClientMixin {
  final _text = TextEditingController();
  final _uuid = const Uuid();
  final _http = http.Client();

  GroupKeyState? _keyState;
  bool _preparing = false;
  String? _status;
  bool _sending = false;

  List<GroupDropRow> _rows = const [];
  final Map<String, _Opened> _opened = {};
  final Map<String, Uint8List> _files = {};

  StreamSubscription<List<GroupDropRow>>? _rowsSub;
  StreamSubscription<void>? _envSub;
  Timer? _healTimer;

  bool _driveOn = false;
  bool _driveConnected = false;
  GroupDriveCopy? _drive;

  String get _gid => widget.group.id;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _rowsSub?.cancel();
    _envSub?.cancel();
    _healTimer?.cancel();
    _text.dispose();
    _http.close();
    super.dispose();
  }

  bool get _online => SupabaseService.instance.isConfigured && SupabaseService.instance.isReachable;

  Future<void> _start() async {
    if (!_online) {
      setState(() => _status = 'Group drops need a connection to NO SUS.');
      return;
    }
    await _initDrive();
    final repo = ref.read(groupDropsRepositoryProvider);
    _rowsSub = repo.watch(_gid).listen(_onRows, onError: (Object e) {
      debugLog('GroupDrops: message stream error: $e');
    });
    _envSub = repo.envelopeChanges(_gid).listen((_) {
      if (_keyState is GroupKeyWaiting) unawaited(_prepare());
    }, onError: (Object e) {
      debugLog('GroupDrops: envelope stream error: $e');
    });
    // New members' devices get the key from whoever has the chat open.
    _healTimer = Timer.periodic(const Duration(seconds: 60), (_) => _heal());
    await _prepare();
  }

  Future<void>? _preparingFuture;

  Future<void> _prepare() {
    return _preparingFuture ??= _prepareOnce().whenComplete(() {
      _preparingFuture = null;
    });
  }

  Future<void> _prepareOnce() async {
    if (!mounted) return;
    setState(() {
      _preparing = true;
      _status = null;
    });
    try {
      final state = await ref.read(groupKeyServiceProvider).prepare(_gid);
      if (!mounted) return;
      setState(() => _keyState = state);
      // Messages that were locked may open now.
      _opened.removeWhere((_, o) => o.lock == _Lock.noKey);
      await _openAll();
    } catch (e) {
      debugLog('GroupDrops: prepare failed: $e');
      if (mounted) setState(() => _status = _setupFailed);
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _heal() async {
    final state = _keyState;
    if (state is! GroupKeyReady) return;
    try {
      await ref.read(groupKeyServiceProvider).heal(_gid, state.epoch, state.key);
    } catch (e) {
      // A rotation may have happened; the next prepare picks it up.
      debugLog('GroupDrops: heal failed: $e');
    }
  }

  void _onRows(List<GroupDropRow> rows) {
    if (!mounted) return;
    setState(() => _rows = rows);
    final ready = _keyState;
    if (ready is GroupKeyReady && rows.any((r) => r.epoch > ready.epoch)) {
      unawaited(_prepare()); // someone rotated the key
    } else {
      unawaited(_openAll());
    }
  }

  Future<void> _openAll() async {
    final service = ref.read(groupKeyServiceProvider);
    final opened = <GroupDropRow>[];
    // One envelope lookup per epoch per pass, including misses.
    final keys = <int, Uint8List?>{};
    for (final row in List.of(_rows)) {
      if (_opened.containsKey(row.id)) continue;
      Uint8List? key;
      if (keys.containsKey(row.epoch)) {
        key = keys[row.epoch];
      } else {
        try {
          key = await service.keyFor(_gid, row.epoch);
        } catch (e) {
          debugLog('GroupDrops: key fetch failed: $e');
        }
        keys[row.epoch] = key;
      }
      if (key == null) {
        _opened[row.id] = const _Opened.locked(_Lock.noKey);
        continue;
      }
      try {
        final payload = openDropMessage(
          groupKey: key,
          groupId: _gid,
          epoch: row.epoch,
          messageId: row.id,
          body: row.body,
        );
        if (row.isFile != (payload.file != null)) throw const FormatException('kind');
        _opened[row.id] = _Opened(payload);
        opened.add(row);
      } catch (_) {
        _opened[row.id] = const _Opened.locked(_Lock.broken);
      }
    }
    if (mounted) setState(() {});
    _copyToDrive(opened);
  }

  // ── Drive copy ────────────────────────────────────────────────────────────

  Future<void> _initDrive() async {
    if (kIsWeb || !GoConfig.isConfigured) return;
    final email = await GoogleDriveAccess.instance.savedEmail();
    var on = await GroupDriveCopy.savedChoice(_gid);
    if (on == null && email != null) {
      on = true; // default on when Drive is connected
      await GroupDriveCopy.setEnabled(_gid, true);
    }
    if (!mounted) return;
    setState(() {
      _driveConnected = email != null;
      _driveOn = on == true && email != null;
      _drive = _driveOn ? _makeDrive() : null;
    });
  }

  GroupDriveCopy _makeDrive() => GroupDriveCopy(
        groupId: _gid,
        groupName: widget.group.name,
        store: DriveSavedStore(
          client: _http,
          token: () => GoogleDriveAccess.instance.accessToken(),
        ),
        onError: (e) {
          if (!mounted) return;
          final msg = e is DriveFailure ? e.message : 'Drive copy failed.';
          setState(() => _status = 'Drive copy paused: $msg');
        },
      );

  Future<void> _setDrive(bool on) async {
    if (on && !_driveConnected) {
      try {
        final email = await GoogleDriveAccess.instance.connect();
        if (email == null) return;
        _driveConnected = true;
      } on DriveFailure catch (e) {
        if (mounted) setState(() => _status = e.message);
        return;
      }
    }
    await GroupDriveCopy.setEnabled(_gid, on);
    if (!mounted) return;
    setState(() {
      _driveOn = on;
      _drive = on ? _makeDrive() : null;
    });
  }

  void _copyToDrive(List<GroupDropRow> rows) {
    final drive = _drive;
    if (drive == null || rows.isEmpty) return;
    final names = _names();
    final now = DateTime.now();
    final items = <DriveCopyItem>[];
    for (final row in rows) {
      final payload = _opened[row.id]?.payload;
      if (payload == null) continue;
      final file = payload.file;
      final fileAlive = file != null && now.difference(row.createdAt) < _fileRetention;
      items.add(DriveCopyItem(
        id: row.id,
        createdAt: row.createdAt,
        sender: names[row.senderId] ?? 'Former member',
        text: payload.text,
        file: fileAlive ? file : null,
        loadFile: fileAlive ? () => _fileBytes(row, file) : null,
      ));
    }
    unawaited(drive.copy(items));
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > groupDropsMaxTextChars) {
      _snack('Messages are limited to $groupDropsMaxTextChars characters.');
      return;
    }
    final ok = await _send(DropPayload(text: text));
    if (ok) _text.clear();
  }

  Future<void> _pick({required bool photo}) async {
    if (_sending) return;
    final picked = await FilePicker.pickFiles(
      type: photo ? FileType.image : FileType.any,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    if (bytes.length > groupDropsMaxFileBytes) {
      _snack('Files can be up to 25 MB.');
      return;
    }
    final caption = _text.text.trim();
    final fileKey = randomBytes(32);
    final ref0 = DropFileRef(
      name: safeDropFileName(file.name),
      mime: _mime(file.extension),
      size: bytes.length,
      key: fileKey,
    );
    final ok = await _send(
      DropPayload(
        text: caption.isEmpty || caption.length > groupDropsMaxTextChars ? null : caption,
        file: ref0,
      ),
      fileBytes: bytes,
    );
    if (ok && caption.isNotEmpty) _text.clear();
  }

  Future<bool> _send(DropPayload payload, {Uint8List? fileBytes}) async {
    final initial = _keyState;
    if (initial is! GroupKeyReady) return false;
    var state = initial;
    setState(() => _sending = true);
    final repo = ref.read(groupDropsRepositoryProvider);
    final id = _uuid.v4();
    try {
      String? path;
      final file = payload.file;
      if (file != null && fileBytes != null) {
        path = groupAttachmentPath(_gid, id);
        await repo.upload(
          path,
          sealDropFile(fileKey: file.key, groupId: _gid, messageId: id, bytes: fileBytes),
        );
        _files[id] = fileBytes;
      }
      for (var attempt = 0;; attempt++) {
        try {
          await repo.insert(
            id: id,
            groupId: _gid,
            epoch: state.epoch,
            kind: file == null ? 'text' : 'file',
            body: sealDropMessage(
              groupKey: state.key,
              groupId: _gid,
              epoch: state.epoch,
              messageId: id,
              payload: payload,
            ),
            attachmentPath: path,
          );
          break;
        } on PostgrestException {
          // Most likely the key rotated under us: the insert policy only
          // accepts the current epoch. Refresh once and re-seal.
          if (attempt > 0) rethrow;
          await _prepare();
          final fresh = _keyState;
          if (fresh is! GroupKeyReady) rethrow;
          state = fresh;
        }
      }
      _opened[id] = _Opened(payload);
      final sent = GroupDropRow(
        id: id,
        groupId: _gid,
        epoch: state.epoch,
        senderId: ref.read(authStateProvider).value?.id ?? '',
        kind: file == null ? 'text' : 'file',
        body: '',
        attachmentPath: path,
        createdAt: DateTime.now(),
      );
      _copyToDrive([sent]);
      unawaited(_heal());
      return true;
    } catch (e) {
      debugLog('GroupDrops: send failed: $e');
      _snack('Couldn’t send. Check your connection and try again.');
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'csv':
        return 'text/csv';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Future<Uint8List> _fileBytes(GroupDropRow row, DropFileRef file) async {
    final cached = _files[row.id];
    if (cached != null) return cached;
    final path = row.attachmentPath;
    if (path == null) throw StateError('no attachment');
    final sealed = await ref.read(groupDropsRepositoryProvider).download(path);
    final bytes = openDropFile(fileKey: file.key, groupId: _gid, messageId: row.id, sealed: sealed);
    if (bytes.length > 8 * 1024 * 1024) return bytes; // don't pin big files in memory
    if (_files.length >= 12) _files.remove(_files.keys.first);
    _files[row.id] = bytes;
    return bytes;
  }

  Future<void> _openFile(GroupDropRow row, DropFileRef file) async {
    if (DateTime.now().difference(row.createdAt) >= _fileRetention && !_files.containsKey(row.id)) {
      _snack('This file was deleted from the relay after 7 days.');
      return;
    }
    Uint8List bytes;
    try {
      bytes = await _fileBytes(row, file);
    } catch (e) {
      debugLog('GroupDrops: file open failed: $e');
      _snack('Couldn’t open this file. It may have been deleted.');
      return;
    }
    if (!mounted) return;
    if (file.isImage) {
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(
                    bytes,
                    semanticLabel: file.name,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('This image can’t be shown here. Use Share to open it.'),
                    ),
                  ),
                ),
              ),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _share(bytes, file),
                    child: const Text('Share'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      await _share(bytes, file);
    }
  }

  Future<void> _share(Uint8List bytes, DropFileRef file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: safeDropFileName(file.name), mimeType: file.mime)],
      ),
    );
  }

  // ── Message actions ───────────────────────────────────────────────────────

  void _actions(GroupDropRow row, DropPayload? payload, bool mine) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (payload?.text != null)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy text'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: payload!.text!));
                  Navigator.pop(sheet);
                },
              ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete from the relay'),
                subtitle: const Text('Anyone who already opened or saved it keeps their copy.'),
                onTap: () async {
                  Navigator.pop(sheet);
                  try {
                    await ref.read(groupDropsRepositoryProvider).delete(row);
                  } catch (_) {
                    _snack('Couldn’t delete. Try again.');
                  }
                },
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report sender'),
                subtitle: const Text('NO SUS can’t read this message. Describe it in the report if you want.'),
                onTap: () {
                  Navigator.pop(sheet);
                  showContentReportSheet(
                    context,
                    targetKind: 'member',
                    targetId: row.senderId,
                    groupId: _gid,
                    headline: 'Report this sender',
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  List<GroupMember> _members(List<GroupMember>? live) =>
      live == null || live.isEmpty ? widget.group.members : live;

  Map<String, String> _names() {
    final members = _members(ref.read(groupMembersProvider(_gid)).value);
    return {for (final m in members) m.id: m.name};
  }

  // ── Info sheet ────────────────────────────────────────────────────────────

  void _info() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => _DropsInfoSheet(
        group: widget.group,
        names: _names(),
        loadKeys: () => ref.read(groupKeyServiceProvider).api.memberDeviceKeys(_gid),
        driveAvailable: !kIsWeb && GoConfig.isConfigured,
        driveOn: _driveOn,
        onDrive: (on) async {
          await _setDrive(on);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? NoSusTheme.dText : NoSusTheme.lText;
    final subtle = isDark ? NoSusTheme.dTextSecondary : NoSusTheme.lTextSecondary;
    final me = ref.watch(authStateProvider).value?.id;
    final members = _members(ref.watch(groupMembersProvider(_gid)).value);
    final names = {for (final m in members) m.id: m.name};

    // Membership changed: heal new devices, or rotate if someone left.
    ref.listen(groupMembersProvider(_gid), (prev, next) {
      final before = prev?.value?.map((m) => m.id).toSet();
      final after = next.value?.map((m) => m.id).toSet();
      if (before == null || after == null || _keyState is! GroupKeyReady) return;
      if (before.length != after.length || !before.containsAll(after)) {
        unawaited(_prepare());
      }
    });

    final state = _keyState;
    final ready = state is GroupKeyReady;

    return Column(
      children: [
        _EncryptionHeader(fg: fg, subtle: subtle, onInfo: _info),
        if (state is GroupKeyWaiting)
          _Notice(
            fg: fg,
            icon: Icons.hourglass_empty,
            text: 'Waiting for a member to let this device in. It happens on its own once '
                'someone in the group has this chat open.',
          ),
        if (state is GroupKeyNoDevice)
          _Notice(fg: fg, icon: Icons.lock_outline, text: 'Sign in to use group drops.'),
        if (_status != null)
          _Notice(
            fg: fg,
            icon: Icons.info_outline,
            text: _status!,
            onTap: _online && _status == _setupFailed ? _prepare : null,
          ),
        Expanded(
          child: _rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                        child: Text(
                          _preparing && _keyState == null
                              ? 'Setting up encryption…'
                              : 'No drops yet. Send a note, a link, a photo or a file to the group.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subtle, fontSize: 14),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final row = _rows[_rows.length - 1 - i];
                      final opened = _opened[row.id];
                      final mine = row.senderId == me;
                      return _DropBubble(
                        key: ValueKey(row.id),
                        row: row,
                        opened: opened,
                        mine: mine,
                        sender: mine ? 'You' : (names[row.senderId] ?? 'Former member'),
                        fg: fg,
                        subtle: subtle,
                        isDark: isDark,
                        onOpenFile: (file) => _openFile(row, file),
                        onLongPress: () => _actions(row, opened?.payload, mine),
                      );
                    },
                  ),
        ),
        _Composer(
          controller: _text,
          enabled: ready && !_sending,
          sending: _sending,
          fg: fg,
          onSend: _sendText,
          onPhoto: () => _pick(photo: true),
          onFile: () => _pick(photo: false),
        ),
      ],
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────────

class _EncryptionHeader extends StatelessWidget {
  final Color fg;
  final Color subtle;
  final VoidCallback onInfo;

  const _EncryptionHeader({required this.fg, required this.subtle, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onInfo,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_encryptionLine, style: TextStyle(fontSize: 12, color: subtle, height: 1.35)),
              ),
              IconButton(
                tooltip: 'Encryption and safety codes',
                onPressed: onInfo,
                icon: Icon(Icons.info_outline, size: 20, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final Color fg;
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _Notice({required this.fg, required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: fg.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final RegExp _url = RegExp(r'https?://[^\s<>"]+');

class _DropBubble extends StatelessWidget {
  final GroupDropRow row;
  final _Opened? opened;
  final bool mine;
  final String sender;
  final Color fg;
  final Color subtle;
  final bool isDark;
  final ValueChanged<DropFileRef> onOpenFile;
  final VoidCallback onLongPress;

  const _DropBubble({
    super.key,
    required this.row,
    required this.opened,
    required this.mine,
    required this.sender,
    required this.fg,
    required this.subtle,
    required this.isDark,
    required this.onOpenFile,
    required this.onLongPress,
  });

  String _time(DateTime t) {
    final now = DateTime.now();
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (t.year == now.year && t.month == now.month && t.day == now.day) return hm;
    return '${t.day}/${t.month} $hm';
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final payload = opened?.payload;
    final lock = opened?.lock;
    final children = <Widget>[
      Text(
        sender,
        style: TextStyle(color: subtle, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 4),
    ];

    if (opened == null) {
      children.add(Text('Decrypting…', style: TextStyle(color: subtle, fontSize: 14)));
    } else if (lock == _Lock.noKey) {
      children.add(Text(
        'This device doesn’t have the key for this message.',
        style: TextStyle(color: subtle, fontSize: 14, fontStyle: FontStyle.italic),
      ));
    } else if (lock == _Lock.broken) {
      children.add(Text(
        'This message didn’t decrypt. It may have been changed on the way.',
        style: TextStyle(color: subtle, fontSize: 14, fontStyle: FontStyle.italic),
      ));
    } else if (payload != null) {
      final file = payload.file;
      if (file != null) {
        final expired = DateTime.now().difference(row.createdAt) >= _fileRetention;
        children.add(
          Semantics(
            button: !expired,
            label: expired ? '${file.name}, deleted after 7 days' : 'Open ${file.name}',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: expired ? null : () => onOpenFile(file),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      file.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
                      color: fg,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            expired
                                ? 'Deleted from the relay after 7 days'
                                : '${_size(file.size)} · Tap to open',
                            style: TextStyle(color: subtle, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final text = payload.text;
      if (text != null) {
        if (file != null) children.add(const SizedBox(height: 6));
        children.add(SelectableText(text, style: TextStyle(color: fg, fontSize: 15, height: 1.4)));
        final link = _url.firstMatch(text)?.group(0);
        final uri = link == null ? null : Uri.tryParse(link);
        if (uri != null) {
          children.add(
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(uri.host.isEmpty ? 'Open link' : 'Open ${uri.host}'),
              ),
            ),
          );
        }
      }
    }

    children.add(const SizedBox(height: 4));
    children.add(Text(_time(row.createdAt), style: TextStyle(color: subtle, fontSize: 11)));

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8 > 420 ? 420 : MediaQuery.sizeOf(context).width * 0.8),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine
                  ? fg.withValues(alpha: isDark ? 0.14 : 0.07)
                  : (isDark ? NoSusTheme.dCard : NoSusTheme.lCard),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: fg.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final Color fg;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onFile;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.fg,
    required this.onSend,
    required this.onPhoto,
    required this.onFile,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Send a photo',
              onPressed: enabled ? onPhoto : null,
              icon: const Icon(Icons.photo_outlined),
            ),
            IconButton(
              tooltip: 'Send a file',
              onPressed: enabled ? onFile : null,
              icon: const Icon(Icons.attach_file),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message or link',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 48,
              height: 48,
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton.filled(
                      tooltip: 'Send',
                      onPressed: enabled ? onSend : null,
                      icon: const Icon(Icons.send, size: 20),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropsInfoSheet extends StatefulWidget {
  final StudyGroup group;
  final Map<String, String> names;
  final Future<List<MemberDeviceKey>> Function() loadKeys;
  final bool driveAvailable;
  final bool driveOn;
  final Future<void> Function(bool on) onDrive;

  const _DropsInfoSheet({
    required this.group,
    required this.names,
    required this.loadKeys,
    required this.driveAvailable,
    required this.driveOn,
    required this.onDrive,
  });

  @override
  State<_DropsInfoSheet> createState() => _DropsInfoSheetState();
}

class _DropsInfoSheetState extends State<_DropsInfoSheet> {
  late Future<List<MemberDeviceKey>> _keys = widget.loadKeys();
  late bool _driveOn = widget.driveOn;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).colorScheme.onSurface;
    final subtle = fg.withValues(alpha: 0.65);
    final title = Theme.of(context).textTheme.titleMedium;
    TextStyle body() => TextStyle(color: fg, fontSize: 14, height: 1.45);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('Group drops', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Messages and files are encrypted on the sender’s device and can only be opened on '
            'the member devices they were sealed to. NO SUS stores them encrypted, deletes '
            'messages after 30 days and files after 7 days.',
            style: body(),
          ),
          const SizedBox(height: 16),
          Text('What NO SUS can still see', style: title),
          const SizedBox(height: 6),
          Text(
            'Who is in the group, who sent each message and when, and roughly how big it was. '
            'Screenshots and copies made by members are outside what encryption can stop.',
            style: body(),
          ),
          const SizedBox(height: 16),
          Text('When someone leaves', style: title),
          const SizedBox(height: 6),
          Text(
            'When an admin removes or bans someone, the group moves to a new key that only the '
            'remaining members get. If someone leaves on their own, the next member to open this '
            'chat does the same. The person who left keeps whatever they already opened or saved.',
            style: body(),
          ),
          const SizedBox(height: 20),
          Text('Safety codes', style: title),
          const SizedBox(height: 6),
          Text(
            'NO SUS hands out the device keys messages are sealed to. Compare with the other '
            'person in person: if the codes on both phones match, nobody’s key was swapped.',
            style: body(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<MemberDeviceKey>>(
            future: _keys,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return TextButton(
                  onPressed: () => setState(() => _keys = widget.loadKeys()),
                  child: const Text('Couldn’t load device keys. Retry'),
                );
              }
              final keys = snap.data ?? const [];
              if (keys.isEmpty) {
                return Text('No member has opened this chat yet.', style: TextStyle(color: subtle));
              }
              final byUser = <String, List<MemberDeviceKey>>{};
              for (final k in keys) {
                (byUser[k.userId] ??= []).add(k);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CodeRow(
                    label: 'Whole group',
                    detail: '${keys.length} device${keys.length == 1 ? '' : 's'}',
                    code: safetyCode([for (final k in keys) k.publicKey]),
                    fg: fg,
                    subtle: subtle,
                  ),
                  const Divider(height: 24),
                  for (final entry in byUser.entries)
                    _CodeRow(
                      label: widget.names[entry.key] ?? 'Member',
                      detail: [
                        '${entry.value.length} device${entry.value.length == 1 ? '' : 's'}',
                        if (entry.value.any((k) => k.kind == 'web'))
                          'includes a browser key, which is weaker than a phone key',
                      ].join(' · '),
                      code: safetyCode([for (final k in entry.value) k.publicKey]),
                      fg: fg,
                      subtle: subtle,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Your Drive copy', style: title),
          const SizedBox(height: 6),
          if (widget.driveAvailable) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Save to my Drive'),
              subtitle: Text(
                'While this chat is open on this phone, new messages go into a daily note and '
                'files are saved in Google Drive › NO SUS › Groups › '
                '${DriveSavedStore.groupFolderName(widget.group.name)}. Copies in your Drive are '
                'not end-to-end encrypted; your Google account protects them.',
              ),
              value: _driveOn,
              onChanged: (on) async {
                await widget.onDrive(on);
                if (mounted) setState(() => _driveOn = on);
              },
            ),
          ] else
            Text(
              kIsWeb
                  ? 'Drive copies are made by your phone.'
                  : 'Drive copies need a build with Google Drive set up.',
              style: TextStyle(color: subtle),
            ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String label;
  final String detail;
  final String code;
  final Color fg;
  final Color subtle;

  const _CodeRow({
    required this.label,
    required this.detail,
    required this.code,
    required this.fg,
    required this.subtle,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label safety code ${code.split('').join(' ')}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                  Text(detail, style: TextStyle(color: subtle, fontSize: 12)),
                ],
              ),
            ),
            SelectableText(
              code,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
