import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Saved/Go session crypto. Phone and the borrowed-computer page both
/// implement this byte layout; the vectors in test/unit and
/// homepage/scripts/nosus-seal.test.cjs lock them together.
///
/// Z is the ECDH P-256 X coordinate, left-padded to 32 bytes.
/// HKDF-SHA256(salt=sid, info="nosus-go/1"‖dpk‖ppk, L=66)
///   → k_pd (32) ‖ k_dp (32) ‖ match (2). Match code is that uint16 mod 100.
/// AES-256-GCM nonce is direction as uint32 BE ‖ seq as uint64 BE.
/// AAD is utf8("nosus-go/1") ‖ sid ‖ direction byte ‖ seq as uint64 BE.
/// Direction 1 is phone→desk (k_pd). Direction 2 is desk→phone (k_dp).

final ECDomainParameters _p256 = ECDomainParameters('prime256v1');

class GoKeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  const GoKeyPair({required this.privateKey, required this.publicKey});
}

class GoKeyMaterial {
  final Uint8List kPd;
  final Uint8List kDp;
  final int matchCode;

  const GoKeyMaterial({
    required this.kPd,
    required this.kDp,
    required this.matchCode,
  });
}

String b64url(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List b64urlDecode(String value) {
  final pad = (4 - value.length % 4) % 4;
  return base64Url.decode(value + ('=' * pad));
}

Uint8List randomBytes(int length) {
  final out = Uint8List(length);
  final rng = Random.secure();
  for (var i = 0; i < length; i++) {
    out[i] = rng.nextInt(256);
  }
  return out;
}

BigInt _big(Uint8List bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

Uint8List _fixed(BigInt value, int length) {
  if (value.isNegative) throw const FormatException('negative coordinate');
  final out = Uint8List(length);
  var n = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (n & BigInt.from(0xff)).toInt();
    n >>= 8;
  }
  if (n != BigInt.zero) throw const FormatException('coordinate too wide');
  return out;
}

/// Uncompressed P-256 point. Rejects the wrong length, off-curve points,
/// and the point at infinity.
ECPoint decodeGoPublic(Uint8List raw) {
  if (raw.length != 65 || raw[0] != 0x04) {
    throw const FormatException('public key');
  }
  final point = _p256.curve.decodePoint(raw);
  if (point == null || point.isInfinity) {
    throw const FormatException('public key');
  }
  final x = point.x?.toBigInteger();
  final y = point.y?.toBigInteger();
  if (x == null || y == null || !_onCurve(x, y)) {
    throw const FormatException('public key');
  }
  return point;
}

bool _onCurve(BigInt x, BigInt y) {
  final p = BigInt.parse(
    'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
    radix: 16,
  );
  final b = BigInt.parse(
    '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
    radix: 16,
  );
  if (x.sign <= 0 || y.sign <= 0 || x >= p || y >= p) return false;
  final a = p - BigInt.from(3);
  final left = (y * y) % p;
  final right = (((x * x * x) % p) + ((a * x) % p) + b) % p;
  return left == right;
}

GoKeyPair generateGoKeyPair() {
  final rng = FortunaRandom()..seed(KeyParameter(randomBytes(32)));
  final gen = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(_p256), rng));
  final pair = gen.generateKeyPair();
  final priv = pair.privateKey as ECPrivateKey;
  final pub = pair.publicKey as ECPublicKey;
  final q = pub.Q!;
  final raw = Uint8List(65)
    ..[0] = 0x04
    ..setRange(1, 33, _fixed(q.x!.toBigInteger()!, 32))
    ..setRange(33, 65, _fixed(q.y!.toBigInteger()!, 32));
  decodeGoPublic(raw);
  return GoKeyPair(
    privateKey: _fixed(priv.d!, 32),
    publicKey: raw,
  );
}

/// Public point for a known scalar. Used by the cross-language vector.
GoKeyPair keyPairFromPrivate(Uint8List privateKey) {
  if (privateKey.length != 32) throw const FormatException('private key');
  final point = _p256.G * _big(privateKey);
  if (point == null || point.isInfinity) {
    throw const FormatException('private key');
  }
  final raw = Uint8List(65)
    ..[0] = 0x04
    ..setRange(1, 33, _fixed(point.x!.toBigInteger()!, 32))
    ..setRange(33, 65, _fixed(point.y!.toBigInteger()!, 32));
  decodeGoPublic(raw);
  return GoKeyPair(privateKey: Uint8List.fromList(privateKey), publicKey: raw);
}

Uint8List sharedSecret(Uint8List privateKey, Uint8List publicKey) {
  if (privateKey.length != 32) throw const FormatException('private key');
  final agree = ECDHBasicAgreement()
    ..init(ECPrivateKey(_big(privateKey), _p256));
  return _fixed(agree.calculateAgreement(ECPublicKey(decodeGoPublic(publicKey), _p256)), 32);
}

Uint8List hkdfSha256({
  required Uint8List ikm,
  required Uint8List salt,
  required Uint8List info,
  required int length,
}) {
  final prk = Uint8List.fromList(Hmac(sha256, salt).convert(ikm).bytes);
  final out = BytesBuilder(copy: false);
  var previous = Uint8List(0);
  var counter = 1;
  while (out.length < length) {
    final block = BytesBuilder(copy: false)
      ..add(previous)
      ..add(info)
      ..addByte(counter);
    previous = Uint8List.fromList(Hmac(sha256, prk).convert(block.toBytes()).bytes);
    out.add(previous);
    counter++;
  }
  return Uint8List.sublistView(out.toBytes(), 0, length);
}

GoKeyMaterial deriveGoKeys({
  required Uint8List z,
  required Uint8List sid,
  required Uint8List dpk,
  required Uint8List ppk,
}) {
  if (z.length != 32 || sid.length != 16) {
    throw const FormatException('key input');
  }
  decodeGoPublic(dpk);
  decodeGoPublic(ppk);
  final info = (BytesBuilder(copy: false)
        ..add(utf8.encode('nosus-go/1'))
        ..add(dpk)
        ..add(ppk))
      .toBytes();
  final okm = hkdfSha256(ikm: z, salt: sid, info: info, length: 66);
  return GoKeyMaterial(
    kPd: Uint8List.fromList(okm.sublist(0, 32)),
    kDp: Uint8List.fromList(okm.sublist(32, 64)),
    matchCode: ((okm[64] << 8) | okm[65]) % 100,
  );
}

Uint8List goNonce(int direction, int seq) {
  final nonce = Uint8List(12);
  ByteData.sublistView(nonce)
    ..setUint32(0, direction, Endian.big)
    ..setUint64(4, seq, Endian.big);
  return nonce;
}

Uint8List goAad(Uint8List sid, int direction, int seq) {
  final seqBytes = Uint8List(8);
  ByteData.sublistView(seqBytes).setUint64(0, seq, Endian.big);
  return (BytesBuilder(copy: false)
        ..add(utf8.encode('nosus-go/1'))
        ..add(sid)
        ..add([direction & 0xff])
        ..add(seqBytes))
      .toBytes();
}

Uint8List _gcm({
  required bool encrypting,
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List data,
  required Uint8List aad,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      encrypting,
      AEADParameters(KeyParameter(key), 128, nonce, aad),
    );
  return cipher.process(data);
}

/// File bytes in transit. The key rides inside the sealed session, not in
/// the storage object. AAD is fixed so a swapped blob fails to open.
Uint8List sealBytes(Uint8List key, Uint8List nonce, Uint8List data) {
  return _gcm(
    encrypting: true,
    key: key,
    nonce: nonce,
    data: data,
    aad: utf8.encode('nosus-go-file'),
  );
}

Uint8List openBytes(Uint8List key, Uint8List nonce, Uint8List box) {
  return _gcm(
    encrypting: false,
    key: key,
    nonce: nonce,
    data: box,
    aad: utf8.encode('nosus-go-file'),
  );
}

Uint8List sealJson({
  required Uint8List key,
  required Uint8List sid,
  required int direction,
  required int seq,
  required Map<String, dynamic> event,
}) {
  return _gcm(
    encrypting: true,
    key: key,
    nonce: goNonce(direction, seq),
    data: Uint8List.fromList(utf8.encode(jsonEncode(event))),
    aad: goAad(sid, direction, seq),
  );
}

Map<String, dynamic> openJson({
  required Uint8List key,
  required Uint8List sid,
  required int direction,
  required int seq,
  required Uint8List box,
}) {
  final plain = _gcm(
    encrypting: false,
    key: key,
    nonce: goNonce(direction, seq),
    data: box,
    aad: goAad(sid, direction, seq),
  );
  final decoded = jsonDecode(utf8.decode(plain));
  if (decoded is! Map) throw const FormatException('event');
  return Map<String, dynamic>.from(decoded);
}
