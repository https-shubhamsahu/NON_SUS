import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/device_keys.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';
import 'package:no_sus/features/address/drop/drop_manifest.dart';
import 'package:no_sus/features/address/drop/drop_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _hex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
    ]);

String _toHex(Uint8List b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  // Same values as homepage/scripts/drop-api.test.cjs.
  const dropId = '00000000-0000-4000-8000-000000000001';
  const manifestJson =
      '{"v":1,"k":"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU","n":"photo.jpg","m":"image/jpeg","s":10,"from":"Asha","note":"hi"}';
  const expectedBox =
      '01045b36890dacbd7c9a96bb74a1ee28b3d2d75b72e09a20ef25cf8e6fd8a9f0350d0e14bed8d4682a34d83538bdff5b96e89a6666ec0db5745d02fa1210072df75a000102030405060708090a0b0fbfff41753e52536ac4cbb60172d23df558b7026c38fb9edb98606fc133d590c2d3d8c67106060d5e992ab379993a67d563ac5fbe222eee263a903e72645ea439f2b8b76f69f3138726670f01b16e17eefb2c21702eb60895a488b5f19312ea3cc96511d2b9adb4455dd759ba24abb1b6e72180c8dc47a4155d7e3a95eb2648a50449debeccdb523fa5fe';
  const expectedFile = '0c0d0e0f101112131415161723aa12d9c82504cf54599f9f52b2c0d13d874922f5ee662b6809';
  final fileKey = Uint8List(32)..fillRange(0, 32, 0x55);
  final recip = keyPairFromPrivate(_hex('33' * 32));
  final eph = keyPairFromPrivate(_hex('44' * 32));

  group('AddressHandle', () {
    test('accepts the shapes the server accepts', () {
      for (final good in ['abcd', 'a' * 20, 'al-ce', '0000', 'asha-2026']) {
        expect(AddressHandle.isValid(good), isTrue, reason: good);
      }
    });

    test('refuses reserved, short, long, and odd handles', () {
      for (final bad in [
        'app', 'www', 'go', 'to', 'admin', 'no-sus', 'settings', 'abc', 'a' * 21,
        '-abc', 'abc-', 'ab--cd', 'xn--abc', 'al_ce', 'al ce', 'é-name', 'ABCD',
      ]) {
        expect(AddressHandle.isValid(bad), isFalse, reason: bad);
      }
      expect(AddressHandle.problem('support'), 'That one is reserved.');
    });

    test('normalizes and builds links', () {
      expect(AddressHandle.normalize('  @Asha-9 '), 'asha-9');
      expect(AddressHandle.link('asha').toString(), 'https://nosus.foo/to?h=asha');
      expect(AddressHandle.subdomain('asha'), 'asha.nosus.foo');
    });
  });

  group('DropManifest', () {
    test('parses the web manifest and writes the same JSON back', () {
      final m = DropManifest.parse(_utf8(manifestJson));
      expect(m.from, 'Asha');
      expect(m.note, 'hi');
      expect(m.size, 10);
      expect(m.fileKey, fileKey);
      expect(jsonEncode(m.toJson()), manifestJson);
    });

    test('rejects malformed manifests', () {
      const k = 'VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU';
      for (final bad in [
        '{"v":2,"k":"$k","n":"a","m":"","s":1,"from":"x","note":""}',
        '{"v":1,"k":"AAAA","n":"a","m":"","s":1,"from":"x","note":""}',
        '{"v":1,"k":"$k","n":"","m":"","s":1,"from":"x","note":""}',
        '{"v":1,"k":"$k","n":"a","m":"","s":-1,"from":"x","note":""}',
        '{"v":1,"k":"$k","n":"a","m":"","s":1,"from":"","note":""}',
        '{"v":1,"k":"$k","n":"a","m":"","s":1,"from":"${'x' * 41}","note":""}',
        '{"v":1,"k":"$k","n":"a","m":"","s":1,"from":"x","note":"${'y' * 281}"}',
        '[]',
        'not json',
      ]) {
        expect(() => DropManifest.parse(_utf8(bad)), throwsFormatException, reason: bad);
      }
    });

    test('a note of 280 emoji is fine (counted by code point)', () {
      final note = '😀' * 280;
      final json = manifestJson.replaceFirst('"note":"hi"', '"note":"$note"');
      expect(DropManifest.parse(_utf8(json)).note, note);
    });

    test('names and types from a stranger are made safe', () {
      final m = DropManifest(
        fileKey: fileKey,
        name: '../..\\evil\u0000.pdf',
        mime: 'text/html\r\nX-Evil: 1',
        size: 1,
        from: 'x',
        note: '',
      );
      expect(m.safeName.contains('/'), isFalse);
      expect(m.safeName.contains('\\'), isFalse);
      expect(m.safeName.contains('\u0000'), isFalse);
      expect(m.safeName.startsWith('.'), isFalse);
      expect(m.safeMime, 'application/octet-stream');
      expect(DropManifest.parse(_utf8(manifestJson)).safeMime, 'image/jpeg');
      expect(DropManifest.parse(_utf8(manifestJson)).looksLikeImage, isTrue);
    });
  });

  group('crypto', () {
    test('manifest box matches the web vector and is bound to its drop id', () {
      final box = sealBox(
        recipientPublic: recip.publicKey,
        context: dropContext(dropId),
        plain: _utf8(manifestJson),
        ephemeral: eph,
        nonce: _hex('000102030405060708090a0b'),
      );
      expect(_toHex(box), expectedBox);
      expect(
        () => openBox(
          recipientPrivate: recip.privateKey,
          recipientPublic: recip.publicKey,
          context: dropContext('00000000-0000-4000-8000-000000000002'),
          box: box,
        ),
        throwsA(anything),
      );
    });

    test('file ciphertext matches the web vector and opens only under its drop id', () {
      final box = sealWithKey(fileKey, _utf8('file bytes'), dropFileAad(dropId), nonce: _hex('0c0d0e0f1011121314151617'));
      expect(_toHex(box), expectedFile);
      expect(
        utf8.decode(openDropFile((key: fileKey, dropId: dropId, box: box, size: 10))),
        'file bytes',
      );
      expect(
        () => openDropFile((key: fileKey, dropId: '00000000-0000-4000-8000-000000000002', box: box, size: 10)),
        throwsA(anything),
      );
      expect(() => openDropFile((key: fileKey, dropId: dropId, box: box, size: 11)), throwsFormatException);
    });

    test('door check code matches the web one', () {
      expect(safetyCode([eph.publicKey, recip.publicKey]), '1705 0386 8627');
    });

    test('a drop sealed to this device opens through DeviceKeys', () async {
      SharedPreferences.setMockInitialValues({});
      DeviceKeys.overrideForTest(SoftwareDeviceKeyBackend());
      final devicePublic = await DeviceKeys.instance.publicKey();

      final key = randomBytes(32);
      final manifest = DropManifest(
        fileKey: key,
        name: 'notes.pdf',
        mime: 'application/pdf',
        size: 5,
        from: 'Ravi',
        note: 'for tomorrow',
      );
      const id = '11111111-2222-4333-8444-555555555555';
      final envelope = sealBox(
        recipientPublic: devicePublic,
        context: dropContext(id),
        plain: _utf8(jsonEncode(manifest.toJson())),
      );
      final opened = await DropRepository.openManifest(id, b64url(envelope));
      expect(opened.from, 'Ravi');
      expect(opened.note, 'for tomorrow');
      expect(opened.fileKey, key);

      final file = sealWithKey(key, _utf8('hello'), dropFileAad(id));
      expect(file.length, 5 + 28);
      final plain = openDropFile((key: opened.fileKey, dropId: id, box: file, size: opened.size));
      expect(utf8.decode(plain), 'hello');

      // The same envelope does not open as a different drop.
      expect(
        () => DropRepository.openManifest('11111111-2222-4333-8444-000000000000', b64url(envelope)),
        throwsA(anything),
      );
    });
  });
}
