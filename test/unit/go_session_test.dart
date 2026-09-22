import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';
import 'package:no_sus/features/address/go_session.dart';

void main() {
  test('phone and desk derive the same code and ignore a retried hello', () {
    final deskKeys = generateGoKeyPair();
    final phoneKeys = generateGoKeyPair();
    final sid = b64url(randomBytes(16));
    final desk = GoMachine.desk(
      sidB64: sid,
      deskPrivate: deskKeys.privateKey,
      deskPublic: deskKeys.publicKey,
    );
    final phone = GoMachine.phone(
      sidB64: sid,
      deskPublic: deskKeys.publicKey,
      phonePrivate: phoneKeys.privateKey,
      phonePublic: phoneKeys.publicKey,
    );

    final hello = phone.helloWire();
    expect(desk.receive(hello).hello, isTrue);
    expect(desk.matchCode, phone.matchCode);
    expect(desk.receive(hello).hello, isFalse);
    expect(desk.aborted, isFalse);

    final wire = phone.sendEvent({
      't': 'grant',
      'scope': 'items',
      'ids': ['a'],
      'mode': 'receive',
      'exp': 1_800_000_000,
      'idle': 600,
    });
    final incoming = desk.receive(wire);
    expect(parseGrant(incoming.event!)!.canPull('a'), isTrue);
    expect(parseGrant(incoming.event!)!.canPull('b'), isFalse);
    final ack = desk.sendEvent({'t': 'ack'});
    desk.remember(incoming.seq!, ack);
    expect(phone.receive(ack).event!['t'], 'ack');
    expect(desk.receive(wire).resend.single['c'], ack['c']);
  });

  test('a second phone key aborts, and a flipped box aborts', () {
    final deskKeys = generateGoKeyPair();
    final sid = b64url(randomBytes(16));
    final desk = GoMachine.desk(
      sidB64: sid,
      deskPrivate: deskKeys.privateKey,
      deskPublic: deskKeys.publicKey,
    );
    final first = generateGoKeyPair();
    final phone = GoMachine.phone(
      sidB64: sid,
      deskPublic: deskKeys.publicKey,
      phonePrivate: first.privateKey,
      phonePublic: first.publicKey,
    );
    desk.receive(phone.helloWire());
    final rival = generateGoKeyPair();
    final other = GoMachine.phone(
      sidB64: sid,
      deskPublic: deskKeys.publicKey,
      phonePrivate: rival.privateKey,
      phonePublic: rival.publicKey,
    );
    desk.receive(other.helloWire());
    expect(desk.aborted, isTrue);
    expect(desk.abortReason, 'competing');

    final clean = GoMachine.desk(
      sidB64: sid,
      deskPrivate: deskKeys.privateKey,
      deskPublic: deskKeys.publicKey,
    );
    clean.receive(phone.helloWire());
    final box = phone.sendEvent({'t': 'end'});
    final bytes = b64urlDecode(box['c'] as String);
    bytes[0] ^= 0xff;
    clean.receive({...box, 'c': b64url(bytes)});
    expect(clean.aborted, isTrue);
    expect(clean.abortReason, 'tamper');
  });

  test('grants need a scope, and sessions end on expiry or idle', () {
    expect(parseGrant({'t': 'grant', 'scope': 'items', 'ids': [], 'mode': 'receive', 'exp': 10}), isNull);
    expect(parseGrant({'t': 'grant', 'scope': 'all', 'mode': 'nope', 'exp': 10}), isNull);
    expect(
      sessionOver(nowSec: 100, exp: 90, lastInputSec: 80, idleSec: 30),
      isTrue,
    );
    expect(
      sessionOver(nowSec: 100, exp: 200, lastInputSec: 80, idleSec: 30),
      isFalse,
    );
    expect(
      sessionOver(nowSec: 100, exp: 200, lastInputSec: 50, idleSec: 30),
      isTrue,
    );
  });

  test('pairing links parse, and shipped link shapes do not', () {
    final desk = generateGoKeyPair();
    final sid = b64url(randomBytes(16));
    final pairing = GoPairing(sid: sid, deskPublic: desk.publicKey);
    expect(extractGoPairing(Uri.parse(pairing.url))?.sid, sid);
    expect(extractGoPairing(Uri.parse('https://app.nosus.foo/#/go/1.not-a-key')), isNull);
    for (final url in [
      'https://nosus.foo/#/burn/01234567-89ab-cdef-0123-456789abcdef?k=${'a' * 64}&v=${'b' * 32}',
      'https://nosus.foo/#/burnfile/01234567-89ab-cdef-0123-456789abcdef',
      'https://nosus.foo/#/burnfiles/01234567-89ab-cdef-0123-456789abcdef',
      'https://nosus.foo/#/redeem/${'ab' * 32}',
      'https://nosus.foo/#/v/abc123',
      'https://nosus.foo/#/join/invite123',
    ]) {
      expect(extractGoPairing(Uri.parse(url)), isNull, reason: url);
    }
  });
}
