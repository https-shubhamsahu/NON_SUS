import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:no_sus/features/address/drive_saved_store.dart';

void main() {
  test('creates the folder tree when none exists', () async {
    var posts = 0;
    final store = DriveSavedStore(
      token: () async => 'token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        if (request.method == 'GET') {
          return http.Response('{"files":[]}', 200);
        }
        posts++;
        return http.Response('{"id":"id$posts"}', 200);
      }),
    );

    final folders = await store.ensureFolders();
    expect(folders.root, 'id1');
    expect(folders.saved, 'id2');
    expect(folders.messages, 'id3');
    expect(posts, 3);
  });

  test('reuses the oldest tagged folder', () async {
    final store = DriveSavedStore(
      token: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'POST') {
          fail('should not create a second folder');
        }
        return http.Response(
          jsonEncode({
            'files': [
              _file('older'),
              _file('newer'),
            ],
          }),
          200,
        );
      }),
    );
    final folders = await store.ensureFolders();
    expect(folders.root, 'older');
    expect(folders.saved, 'older');
    expect(folders.messages, 'older');
  });

  test('a retried message does not create a second file', () async {
    var uploads = 0;
    final store = DriveSavedStore(
      token: () async => 'token',
      client: MockClient((request) async {
        if (request.url.path.contains('/upload/')) {
          uploads++;
          return http.Response('{"id":"new"}', 200);
        }
        return http.Response(
          jsonEncode({
            'files': [
              _file('existing', nosusId: 'abc123', kind: 'msg'),
            ],
          }),
          200,
        );
      }),
    );
    final item = await store.putMessage(
      messagesFolderId: 'messages',
      nosusId: 'abc123',
      text: 'hello',
      src: 'phone',
    );
    expect(item.driveId, 'existing');
    expect(uploads, 0);
  });

  test('a full Drive is a distinct failure', () async {
    final store = DriveSavedStore(
      token: () async => 'token',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"files":[]}', 200);
        }
        return http.Response(
          jsonEncode({
            'error': {
              'errors': [
                {'reason': 'storageQuotaExceeded'},
              ],
            },
          }),
          403,
        );
      }),
    );
    expect(
      () => store.putMessage(
        messagesFolderId: 'messages',
        nosusId: 'abc123',
        text: 'hello',
        src: 'phone',
      ),
      throwsA(isA<DriveFailure>().having((e) => e.code, 'code', 'full')),
    );
  });
}

Map<String, Object> _file(String id, {String nosusId = '', String kind = ''}) {
  return {
    'id': id,
    'name': 'NO SUS',
    'mimeType': 'application/vnd.google-apps.folder',
    'createdTime': '2026-01-01T00:00:00.000Z',
    'appProperties': {
      'nosus_id': nosusId,
      'nosus_kind': kind,
    },
  };
}
