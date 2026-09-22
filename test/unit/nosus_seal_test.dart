import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';

/// Fixed scalars shared with homepage/scripts/nosus-seal.test.cjs.
/// Expected bytes are Node's ECDH, HKDF, and AES-GCM output.
Uint8List _hex(String value) {
  final out = Uint8List(value.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

void main() {
  test('matches the Node seal vector', () {
    final desk = keyPairFromPrivate(_hex('11' * 32));
    final phone = keyPairFromPrivate(_hex('22' * 32));
    final sid = _hex('00112233445566778899aabbccddeeff');
    final z = sharedSecret(desk.privateKey, phone.publicKey);
    expect(z, sharedSecret(phone.privateKey, desk.publicKey));
    expect(z.length, 32);

    final keys = deriveGoKeys(
      z: z,
      sid: sid,
      dpk: desk.publicKey,
      ppk: phone.publicKey,
    );
    final box = sealJson(
      key: keys.kPd,
      sid: sid,
      direction: 1,
      seq: 1,
      event: const {'t': 'ack'},
    );
    expect(
      openJson(key: keys.kPd, sid: sid, direction: 1, seq: 1, box: box),
      {'t': 'ack'},
    );
    final tampered = Uint8List.fromList(box)..[0] ^= 0xff;
    expect(
      () => openJson(key: keys.kPd, sid: sid, direction: 1, seq: 1, box: tampered),
      throwsA(anything),
    );

    expect(z, _hex('ccfc261f58193c98ca4ad4a53bbac6f0ee29bc4d48438090446908622ca79af6'));
    expect(keys.matchCode, 17);
    expect(
      box,
      _hex('2eb94c049b3b387e603d6d49be41881757d78d13a0da0399cac8bc'),
    );

    final zero = keyPairFromPrivate(
      _hex('00000000000000000000000000000000000000000000000000000000000001f5'),
    );
    final padded = sharedSecret(zero.privateKey, desk.publicKey);
    expect(padded[0], 0);
    expect(
      padded,
      _hex('004c67239b68c9f83e0cda039169795bfcceb6ff8f89374133515ea248f1ff10'),
    );
  });

  test('file seal round-trips and rejects a swapped blob', () {
    final key = _hex('33' * 32);
    final nonce = _hex('44' * 12);
    final box = sealBytes(key, nonce, Uint8List.fromList([1, 2, 3, 4]));
    expect(openBytes(key, nonce, box), [1, 2, 3, 4]);
    final swapped = Uint8List.fromList(box)..[0] ^= 0xff;
    expect(() => openBytes(key, nonce, swapped), throwsA(anything));
  });
}
