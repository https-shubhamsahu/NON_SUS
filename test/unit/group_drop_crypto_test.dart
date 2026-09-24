import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';
import 'package:no_sus/features/groups/drops/group_drop_crypto.dart';

void main() {
  final key = randomBytes(32);
  const gid = 'g_1726000000000';
  const id = '6f1c2a8e-3b1d-4c7e-9a55-0d2f4b6c8e10';

  group('message aad binding', () {
    final body = sealDropMessage(
      groupKey: key,
      groupId: gid,
      epoch: 3,
      messageId: id,
      payload: const DropPayload(text: 'hello group'),
    );

    test('opens with the same group, epoch and id', () {
      final payload = openDropMessage(
        groupKey: key,
        groupId: gid,
        epoch: 3,
        messageId: id,
        body: body,
      );
      expect(payload.text, 'hello group');
      expect(payload.file, isNull);
    });

    test('wrong group fails', () {
      expect(
        () => openDropMessage(groupKey: key, groupId: 'g_other', epoch: 3, messageId: id, body: body),
        throwsA(anything),
      );
    });

    test('wrong epoch fails', () {
      expect(
        () => openDropMessage(groupKey: key, groupId: gid, epoch: 2, messageId: id, body: body),
        throwsA(anything),
      );
    });

    test('wrong message id fails', () {
      expect(
        () => openDropMessage(
          groupKey: key,
          groupId: gid,
          epoch: 3,
          messageId: '00000000-0000-4000-8000-000000000000',
          body: body,
        ),
        throwsA(anything),
      );
    });

    test('wrong key fails', () {
      expect(
        () => openDropMessage(groupKey: randomBytes(32), groupId: gid, epoch: 3, messageId: id, body: body),
        throwsA(anything),
      );
    });

    test('the aad string is the documented one', () {
      expect(utf8.decode(groupMessageAad(gid, 3, id)), 'nosus-group/1:$gid:3:$id');
      expect(utf8.decode(groupFileAad(gid, id)), 'nosus-group-file/1:$gid:$id');
      expect(groupKeyContext(gid, 3), 'group-key:$gid:3');
    });
  });

  group('file seal', () {
    test('round-trips and is bound to the message id', () {
      final fileKey = randomBytes(32);
      final bytes = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
      final sealed = sealDropFile(fileKey: fileKey, groupId: gid, messageId: id, bytes: bytes);
      expect(sealed.length, bytes.length + 28);
      expect(openDropFile(fileKey: fileKey, groupId: gid, messageId: id, sealed: sealed), bytes);
      expect(
        () => openDropFile(fileKey: fileKey, groupId: gid, messageId: 'other', sealed: sealed),
        throwsA(anything),
      );
      expect(
        () => openDropFile(fileKey: fileKey, groupId: 'g_other', messageId: id, sealed: sealed),
        throwsA(anything),
      );
    });

    test('a file payload survives the trip through a message', () {
      final fileKey = randomBytes(32);
      final body = sealDropMessage(
        groupKey: key,
        groupId: gid,
        epoch: 1,
        messageId: id,
        payload: DropPayload(
          text: 'notes',
          file: DropFileRef(name: 'a.pdf', mime: 'application/pdf', size: 10, key: fileKey),
        ),
      );
      final out = openDropMessage(groupKey: key, groupId: gid, epoch: 1, messageId: id, body: body);
      expect(out.text, 'notes');
      expect(out.file!.name, 'a.pdf');
      expect(out.file!.mime, 'application/pdf');
      expect(out.file!.size, 10);
      expect(out.file!.key, fileKey);
    });
  });

  group('payload validation', () {
    final goodKey = b64url(Uint8List(32));
    Map<String, dynamic> file([Map<String, dynamic> over = const {}]) => {
          'n': 'photo.jpg',
          'm': 'image/jpeg',
          's': 1000,
          'k': goodKey,
          ...over,
        };

    test('accepts text, file, and both', () {
      expect(DropPayload.fromJson({'v': 1, 't': 'hi'}).text, 'hi');
      expect(DropPayload.fromJson({'v': 1, 'f': file()}).file!.isImage, isTrue);
      expect(DropPayload.fromJson({'v': 1, 't': 'x', 'f': file()}).text, 'x');
    });

    final bad = <String, Object?>{
      'not a map': ['v', 1],
      'wrong version': {'v': 2, 't': 'hi'},
      'missing version': {'t': 'hi'},
      'empty': {'v': 1},
      'unknown key': {'v': 1, 't': 'hi', 'x': 1},
      'text not a string': {'v': 1, 't': 5},
      'empty text': {'v': 1, 't': ''},
      'text too long': {'v': 1, 't': 'a' * (groupDropsMaxTextChars + 1)},
      'file not a map': {'v': 1, 'f': 'a.pdf'},
      'file missing key': {'v': 1, 'f': {'n': 'a', 'm': 'image/png', 's': 1}},
      'file extra field': {'v': 1, 'f': {...file(), 'x': 1}},
      'file empty name': {'v': 1, 'f': file({'n': ' '})},
      'file long name': {'v': 1, 'f': file({'n': 'a' * 256})},
      'file bad mime': {'v': 1, 'f': file({'m': 'text/html; charset=x'})},
      'file negative size': {'v': 1, 'f': file({'s': -1})},
      'file too big': {'v': 1, 'f': file({'s': groupDropsMaxFileBytes + 1})},
      'file size as string': {'v': 1, 'f': file({'s': '10'})},
      'file short key': {'v': 1, 'f': file({'k': b64url(Uint8List(16))})},
      'file key not b64url': {'v': 1, 'f': file({'k': '+' * 43})},
    };
    for (final entry in bad.entries) {
      test('rejects ${entry.key}', () {
        expect(() => DropPayload.fromJson(entry.value), throwsFormatException);
      });
    }

    test('a sealed non-JSON body fails', () {
      final raw = sealWithKey(
        key,
        Uint8List.fromList(utf8.encode('not json')),
        groupMessageAad(gid, 1, id),
      );
      expect(
        () => openDropMessage(groupKey: key, groupId: gid, epoch: 1, messageId: id, body: b64url(raw)),
        throwsFormatException,
      );
    });
  });

  test('safeDropFileName strips paths and control characters', () {
    expect(safeDropFileName('../../etc/passwd'), 'passwd');
    expect(safeDropFileName(r'C:\x\report.pdf'), 'report.pdf');
    expect(safeDropFileName('a\u0000b.txt'), 'ab.txt');
    expect(safeDropFileName('..'), 'file');
    expect(safeDropFileName(''), 'file');
  });
}
