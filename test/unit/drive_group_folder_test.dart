import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:no_sus/features/address/drive_saved_store.dart';
import 'package:no_sus/features/groups/drops/group_drive_copy.dart';
import 'package:no_sus/features/groups/drops/group_drop_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny fake Drive: folders/files by id, `q` answered for the three query
/// shapes DriveSavedStore sends.
class FakeDrive {
  final Map<String, Map<String, dynamic>> files = {};
  final Map<String, String> content = {};
  final List<String> calls = [];
  var _next = 0;

  MockClient client() => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        calls.add('${request.method} ${request.url.path}');
        final path = request.url.path;
        if (request.method == 'GET' && path == '/drive/v3/files') {
          return http.Response(jsonEncode({'files': _query(request.url.queryParameters['q']!)}), 200);
        }
        if (request.method == 'GET' && path.startsWith('/drive/v3/files/')) {
          return http.Response.bytes(utf8.encode(content[path.split('/').last] ?? ''), 200);
        }
        if (request.method == 'POST' && path == '/drive/v3/files') {
          final meta = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': _add(meta, null)}), 200);
        }
        if (request.method == 'POST' && path == '/upload/drive/v3/files') {
          final body = utf8.decode(request.bodyBytes);
          final metaStart = body.indexOf('{');
          final metaEnd = body.indexOf('\r\n--');
          final meta = jsonDecode(body.substring(metaStart, metaEnd)) as Map<String, dynamic>;
          final partStart = body.indexOf('\r\n\r\n', metaEnd) + 4;
          final partEnd = body.lastIndexOf('\r\n--');
          return http.Response(jsonEncode({'id': _add(meta, body.substring(partStart, partEnd))}), 200);
        }
        if (request.method == 'PATCH' && path.startsWith('/upload/drive/v3/files/')) {
          expect(request.url.queryParameters['uploadType'], 'media');
          content[path.split('/').last] = utf8.decode(request.bodyBytes);
          return http.Response('{}', 200);
        }
        fail('unexpected ${request.method} $path');
      });

  String _add(Map<String, dynamic> meta, String? body) {
    final id = 'f${_next++}';
    files[id] = {
      'id': id,
      'name': meta['name'],
      'mimeType': meta['mimeType'],
      'parents': meta['parents'],
      'createdTime': '2026-09-24T00:00:0$_next.000Z',
      'appProperties': meta['appProperties'],
    };
    if (body != null) content[id] = body;
    return id;
  }

  List<Map<String, dynamic>> _query(String q) {
    final marker = RegExp(r"key='nosus_marker' and value='((?:[^'\\]|\\.)*)'").firstMatch(q);
    final day = RegExp(r"key='nosus_day' and value='([^']*)'").firstMatch(q);
    final parent = RegExp(r"^'([^']*)' in parents").firstMatch(q);
    return files.values.where((f) {
      final props = (f['appProperties'] as Map?) ?? const {};
      if (marker != null) {
        final want = marker.group(1)!.replaceAll(r"\'", "'").replaceAll(r'\\', r'\');
        return props['nosus_marker'] == want;
      }
      if (day != null) {
        return props['nosus_day'] == day.group(1) &&
            (parent == null || (f['parents'] as List).contains(parent.group(1)));
      }
      return false;
    }).toList();
  }
}

void main() {
  late FakeDrive drive;
  late DriveSavedStore store;

  setUp(() {
    drive = FakeDrive();
    store = DriveSavedStore(client: drive.client(), token: () async => 'token');
  });

  test('group folder lives at NO SUS/Groups/<name> with markers', () async {
    final id = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'Physics / 2026');
    final folder = drive.files[id]!;
    expect(folder['name'], 'Physics   2026');
    expect(folder['appProperties'], {'nosus_marker': 'nosus_group:g_1'});

    final groups = drive.files[(folder['parents'] as List).single]!;
    expect(groups['name'], 'Groups');
    expect(groups['appProperties'], {'nosus_marker': DriveSavedStore.markerGroups});

    final root = drive.files[(groups['parents'] as List).single]!;
    expect(root['name'], 'NO SUS');
    expect(root['parents'], ['root']);
  });

  test('the same group reuses its folder; another group gets its own', () async {
    final a = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'One');
    final again = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'Renamed');
    final b = await store.ensureGroupFolder(groupId: 'g_2', groupName: 'Two');
    expect(again, a);
    expect(b, isNot(a));
    // NO SUS and Groups were created once.
    expect(drive.files.values.where((f) => f['name'] == 'Groups'), hasLength(1));
    expect(drive.files.values.where((f) => f['name'] == 'NO SUS'), hasLength(1));
  });

  test('groups share the NO SUS root with Saved', () async {
    final saved = await store.ensureFolders();
    final group = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'One');
    final groups = (drive.files[group]!['parents'] as List).single;
    expect(drive.files[groups]!['parents'], [saved.root]);
  });

  test("a quote in a group id is escaped in the Drive query", () async {
    final a = await store.ensureGroupFolder(groupId: "g_'x", groupName: 'Q');
    final again = await store.ensureGroupFolder(groupId: "g_'x", groupName: 'Q');
    expect(again, a);
  });

  test('transcript: created once per day, appended, retries do not duplicate', () async {
    final folder = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'One');

    expect(
      await store.appendTranscript(
        folderId: folder,
        day: '2026-09-24',
        header: '# One · 2026-09-24',
        lines: ['- 10:00 Asha: hi', '- 10:01 Ravi: hello'],
      ),
      2,
    );
    expect(
      await store.appendTranscript(
        folderId: folder,
        day: '2026-09-24',
        header: '# One · 2026-09-24',
        lines: ['- 10:01 Ravi: hello', '- 10:02 Asha: third'],
      ),
      1,
    );

    final days = drive.files.values.where((f) => f['name'] == '2026-09-24.md').toList();
    expect(days, hasLength(1));
    expect(days.single['parents'], [folder]);
    expect(days.single['appProperties'], {
      'nosus_kind': 'transcript',
      'nosus_day': '2026-09-24',
      'nosus_src': 'phone',
    });
    expect(
      drive.content[days.single['id']],
      '# One · 2026-09-24\n\n- 10:00 Asha: hi\n- 10:01 Ravi: hello\n- 10:02 Asha: third\n',
    );

    await store.appendTranscript(
      folderId: folder,
      day: '2026-09-25',
      header: '# One · 2026-09-25',
      lines: ['- 09:00 Asha: next day'],
    );
    expect(drive.files.values.where((f) => (f['name'] as String).endsWith('.md')), hasLength(2));
  });

  test('transcript rejects a day that is not YYYY-MM-DD', () {
    expect(
      () => store.appendTranscript(folderId: 'x', day: "2026' or '1", header: '', lines: const ['a']),
      throwsArgumentError,
    );
  });

  group('GroupDriveCopy', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('transcript lines are one markdown item each', () {
      final t = DateTime(2026, 9, 24, 9, 5);
      expect(transcriptDay(t), '2026-09-24');
      expect(
        transcriptLine(DriveCopyItem(id: 'a', createdAt: t, sender: 'Asha', text: 'line one\nline two')),
        '- 09:05 Asha: line one\n  line two',
      );
      expect(
        transcriptLine(DriveCopyItem(
          id: 'b',
          createdAt: t,
          sender: 'Ravi',
          text: 'notes',
          file: DropFileRef(name: '../x/report.pdf', mime: 'application/pdf', size: 3, key: Uint8List(32)),
        )),
        '- 09:05 Ravi: sent report.pdf — notes',
      );
    });

    test('off by default: nothing is written', () async {
      final copy = GroupDriveCopy(groupId: 'g_1', groupName: 'One', store: store);
      await copy.copy([DriveCopyItem(id: 'm1', createdAt: DateTime.now(), sender: 'A', text: 'hi')]);
      expect(drive.calls, isEmpty);
    });

    test('copies files and text since it was turned on, once', () async {
      final before = DateTime.now().subtract(const Duration(minutes: 5));
      await GroupDriveCopy.setEnabled('g_1', true);
      final now = DateTime.now().add(const Duration(seconds: 1));
      var loads = 0;
      final items = [
        DriveCopyItem(id: 'old', createdAt: before, sender: 'A', text: 'before the switch'),
        DriveCopyItem(id: 'm1', createdAt: now, sender: 'A', text: 'hello'),
        DriveCopyItem(
          id: '6f1c2a8e-3b1d-4c7e-9a55-0d2f4b6c8e10',
          createdAt: now,
          sender: 'B',
          file: DropFileRef(name: 'a.pdf', mime: 'application/pdf', size: 3, key: Uint8List(32)),
          loadFile: () async {
            loads++;
            return Uint8List.fromList(utf8.encode('pdf'));
          },
        ),
      ];
      final copy = GroupDriveCopy(groupId: 'g_1', groupName: 'One', store: store);
      await copy.copy(items);
      await GroupDriveCopy(groupId: 'g_1', groupName: 'One', store: store).copy(items);

      expect(loads, 1);
      final pdfs = drive.files.values.where((f) => f['name'] == 'a.pdf');
      expect(pdfs, hasLength(1));
      final day = drive.files.values.singleWhere((f) => (f['name'] as String).endsWith('.md'));
      final text = drive.content[day['id']]!;
      expect(text, contains('A: hello'));
      expect(text, contains('B: sent a.pdf'));
      expect(text, isNot(contains('before the switch')));
    });
  });

  test('group attachments go through putFile into the group folder', () async {
    final folder = await store.ensureGroupFolder(groupId: 'g_1', groupName: 'One');
    final item = await store.putFile(
      savedFolderId: folder,
      nosusId: '6f1c2a8e-3b1d-4c7e-9a55-0d2f4b6c8e10',
      name: 'notes.pdf',
      mime: 'application/pdf',
      bytes: utf8.encode('pdf'),
      src: 'group',
    );
    expect(drive.files[item.driveId]!['parents'], [folder]);
    expect(item.src, 'group');
  });
}
