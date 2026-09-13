import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/services/redemption_envelope.dart';

void main() {
  test('pairing envelope round-trips key material with the token and pin', () {
    const token = '0123456789abcdef0123456789abcdef';
    const pin = '47';
    const key = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const iv = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    final envelope = RedemptionEnvelope.seal(
      token: token,
      pin: pin,
      keyHex: key,
      contentIvHex: iv,
    );

    expect(
      RedemptionEnvelope.open(
        token: token,
        pin: pin,
        ciphertextHex: envelope.ciphertextHex,
        envelopeIvHex: envelope.ivHex,
      ),
      (keyHex: key, ivHex: iv),
    );
  });

  test('pairing envelope rejects the wrong pin', () {
    final envelope = RedemptionEnvelope.seal(
      token: '0123456789abcdef0123456789abcdef',
      pin: '47',
      keyHex: List.filled(32, 'aa').join(),
      contentIvHex: List.filled(16, 'bb').join(),
    );

    expect(
      () => RedemptionEnvelope.open(
        token: '0123456789abcdef0123456789abcdef',
        pin: '48',
        ciphertextHex: envelope.ciphertextHex,
        envelopeIvHex: envelope.ivHex,
      ),
      throwsA(anything),
    );
  });
}
