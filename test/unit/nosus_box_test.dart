import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';

Uint8List _hex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
    ]);

String _toHex(Uint8List b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Same vector as homepage/scripts/nosus-box.test.cjs.
  const expected = '01045b36890dacbd7c9a96bb74a1ee28b3d2d75b72e09a20ef25cf8e6fd8a9f0350d0e14bed8d4682a34d83538bdff5b96e89a6666ec0db5745d02fa1210072df75a000102030405060708090a0beae60c25d460db92856999abdafb700c726d34bfaa3544369cf3';
  final recip = keyPairFromPrivate(_hex('33' * 32));
  final eph = keyPairFromPrivate(_hex('44' * 32));

  test('sealBox matches the web vector', () {
    final box = sealBox(
      recipientPublic: recip.publicKey,
      context: 'drop',
      plain: Uint8List.fromList(utf8.encode('hello drop')),
      ephemeral: eph,
      nonce: _hex('000102030405060708090a0b'),
    );
    expect(_toHex(box), expected);
  });

  test('openBox round-trips and binds the context', () {
    final box = _hex(expected);
    final plain = openBox(
      recipientPrivate: recip.privateKey,
      recipientPublic: recip.publicKey,
      context: 'drop',
      box: box,
    );
    expect(utf8.decode(plain), 'hello drop');
    expect(
      () => openBox(
        recipientPrivate: recip.privateKey,
        recipientPublic: recip.publicKey,
        context: 'group-key:x:1',
        box: box,
      ),
      throwsA(anything),
    );
  });

  test('sealWithKey rejects tampering', () {
    final key = Uint8List(32)..fillRange(0, 32, 7);
    final aad = Uint8List.fromList(utf8.encode('nosus-group/1'));
    final box = sealWithKey(key, Uint8List.fromList(utf8.encode('hi')), aad);
    expect(utf8.decode(openWithKey(key, box, aad)), 'hi');
    box[box.length - 1] ^= 1;
    expect(() => openWithKey(key, box, aad), throwsA(anything));
  });

  test('safetyCode is order independent', () {
    final a = recip.publicKey;
    final b = eph.publicKey;
    expect(safetyCode([a, b]), safetyCode([b, a]));
    expect(safetyCode([a, b]), matches(RegExp(r'^\d{4} \d{4} \d{4}$')));
  });
}
