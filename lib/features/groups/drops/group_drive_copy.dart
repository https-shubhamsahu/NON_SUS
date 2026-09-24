import 'dart:async';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../address/drive_saved_store.dart';
import 'group_drop_crypto.dart';

/// One decrypted message to copy into the member's own Drive.
class DriveCopyItem {
  final String id;
  final DateTime createdAt;
  final String sender;
  final String? text;
  final DropFileRef? file;

  /// Downloads and decrypts the attachment. Only called for files.
  final Future<Uint8List> Function()? loadFile;

  const DriveCopyItem({
    required this.id,
    required this.createdAt,
    required this.sender,
    this.text,
    this.file,
    this.loadFile,
  });
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Local calendar day, `YYYY-MM-DD`: the transcript file name.
String transcriptDay(DateTime t) {
  final l = t.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${_two(l.month)}-${_two(l.day)}';
}

/// One markdown list item. Continuation lines are indented so a multi-line
/// message stays one item.
String transcriptLine(DriveCopyItem item) {
  final l = item.createdAt.toLocal();
  final who = item.sender.replaceAll('\n', ' ').trim();
  final parts = <String>[];
  if (item.file != null) {
    parts.add('sent ${safeDropFileName(item.file!.name)}');
  }
  final text = item.text?.trim();
  if (text != null && text.isNotEmpty) parts.add(text.replaceAll('\n', '\n  '));
  return '- ${_two(l.hour)}:${_two(l.minute)} $who: ${parts.join(' — ')}';
}

/// Writes a member's own copy of a group's drops into
/// `NO SUS/Groups/<group name>/` in their Google Drive: files as files,
/// text into a daily transcript. The phone is the only writer, and only
/// while the chat is open. Messages from before the switch was turned on
/// are not copied.
class GroupDriveCopy {
  GroupDriveCopy({
    required this.groupId,
    required this.groupName,
    required this.store,
    this.onError,
  });

  final String groupId;
  final String groupName;
  final DriveSavedStore store;
  final void Function(Object error)? onError;

  String? _folder;
  Future<void> _chain = Future.value();
  final Set<String> _queued = {};

  static String _onKey(String g) => 'group_drops_drive_on_$g';
  static String _sinceKey(String g) => 'group_drops_drive_since_$g';
  static String _doneKey(String g) => 'group_drops_drive_done_$g';
  static const _doneCap = 1000;

  /// Null when the member never chose; the caller picks the default.
  static Future<bool?> savedChoice(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onKey(groupId));
  }

  static Future<void> setEnabled(String groupId, bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onKey(groupId), on);
    if (on && !prefs.containsKey(_sinceKey(groupId))) {
      await prefs.setInt(_sinceKey(groupId), DateTime.now().millisecondsSinceEpoch);
    }
    if (!on) await prefs.remove(_sinceKey(groupId));
  }

  /// Copies [items] that are new since the switch was turned on and were
  /// not copied before. Runs one batch at a time.
  Future<void> copy(List<DriveCopyItem> items) {
    final fresh = items.where((i) => !_queued.contains(i.id)).toList();
    if (fresh.isEmpty) return _chain;
    _queued.addAll(fresh.map((i) => i.id));
    _chain = _chain.then((_) => _run(fresh)).catchError((Object e) {
      _queued.removeAll(fresh.map((i) => i.id));
      onError?.call(e);
    });
    return _chain;
  }

  Future<void> _run(List<DriveCopyItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final sinceMs = prefs.getInt(_sinceKey(groupId));
    if (prefs.getBool(_onKey(groupId)) != true || sinceMs == null) return;
    final since = DateTime.fromMillisecondsSinceEpoch(sinceMs);
    final doneList = prefs.getStringList(_doneKey(groupId)) ?? const <String>[];
    final done = doneList.toSet();
    final todo = items
        .where((i) => !done.contains(i.id) && !i.createdAt.isBefore(since))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (todo.isEmpty) return;

    final folder = _folder ??= await store.ensureGroupFolder(
      groupId: groupId,
      groupName: groupName,
    );

    for (final item in todo) {
      final file = item.file;
      final load = item.loadFile;
      if (file == null || load == null) continue;
      await store.putFile(
        savedFolderId: folder,
        nosusId: item.id,
        name: safeDropFileName(file.name),
        mime: file.mime,
        bytes: await load(),
        src: 'group',
      );
    }

    final byDay = <String, List<String>>{};
    for (final item in todo) {
      (byDay[transcriptDay(item.createdAt)] ??= []).add(transcriptLine(item));
    }
    for (final entry in byDay.entries) {
      await store.appendTranscript(
        folderId: folder,
        day: entry.key,
        header: '# ${DriveSavedStore.groupFolderName(groupName)} · ${entry.key}',
        lines: entry.value,
      );
    }

    final updated = [...doneList, ...todo.map((i) => i.id)];
    await prefs.setStringList(
      _doneKey(groupId),
      updated.length > _doneCap ? updated.sublist(updated.length - _doneCap) : updated,
    );
  }
}
