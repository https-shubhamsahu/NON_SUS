import 'dart:math';
import 'dart:typed_data';

import '../../core/crypto/nosus_seal.dart';

/// QR payload `https://app.nosus.foo/#/go/1.<sid>.<dpk>`.
class GoPairing {
  final String sid;
  final Uint8List deskPublic;

  const GoPairing({required this.sid, required this.deskPublic});

  String get url => 'https://app.nosus.foo/#/go/1.$sid.${b64url(deskPublic)}';
}

final _goPairing = RegExp(
  r'^go/1\.([A-Za-z0-9_-]{22})\.([A-Za-z0-9_-]{87})(?:\?.*)?$',
);

/// Null unless [uri] is a Go pairing link with a real P-256 point.
/// Does not match burn, redeem, share, or join links.
GoPairing? extractGoPairing(Uri uri) {
  for (final raw in [uri.fragment, uri.path]) {
    final cleaned = raw.startsWith('/') ? raw.substring(1) : raw;
    final match = _goPairing.firstMatch(cleaned);
    if (match == null) continue;
    try {
      final sid = b64urlDecode(match.group(1)!);
      final dpk = b64urlDecode(match.group(2)!);
      if (sid.length != 16) return null;
      decodeGoPublic(dpk);
      return GoPairing(sid: match.group(1)!, deskPublic: dpk);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class GoRecv {
  final bool hello;
  final Map<String, dynamic>? event;
  final int? seq;
  final List<Map<String, dynamic>> resend;

  const GoRecv({
    this.hello = false,
    this.event,
    this.seq,
    this.resend = const [],
  });
}

/// Relay state machine. Hello is the only plaintext event, and the first
/// phone key locks the session: the same key again is a retry, a different
/// key aborts. A repeated seq does not run twice; a stored reply is resent.
class GoMachine {
  GoMachine.desk({
    required String sidB64,
    required Uint8List deskPrivate,
    required Uint8List deskPublic,
  }) : this._(
         isPhone: false,
         sidB64: sidB64,
         deskPublic: deskPublic,
         deskPrivate: deskPrivate,
         phonePrivate: null,
         phonePublic: null,
       );

  GoMachine.phone({
    required String sidB64,
    required Uint8List deskPublic,
    required Uint8List phonePrivate,
    required Uint8List phonePublic,
  }) : this._(
         isPhone: true,
         sidB64: sidB64,
         deskPublic: deskPublic,
         deskPrivate: null,
         phonePrivate: phonePrivate,
         phonePublic: phonePublic,
       );

  GoMachine._({
    required this.isPhone,
    required this.sidB64,
    required this.deskPublic,
    required this._deskPrivate,
    required this._phonePrivate,
    required this._phonePublic,
  });

  final bool isPhone;
  final String sidB64;
  final Uint8List deskPublic;
  final Uint8List? _deskPrivate;
  final Uint8List? _phonePrivate;
  Uint8List? _phonePublic;

  bool aborted = false;
  String? abortReason;
  GoKeyMaterial? keys;
  int _sendSeq = 0;
  int _recvSeq = 0;
  final Map<int, Map<String, dynamic>> _replies = {};

  int? get matchCode => keys?.matchCode;

  Uint8List get _sid => b64urlDecode(sidB64);

  void _derive() {
    final mine = isPhone ? _phonePrivate! : _deskPrivate!;
    final theirs = isPhone ? deskPublic : _phonePublic!;
    keys = deriveGoKeys(
      z: sharedSecret(mine, theirs),
      sid: _sid,
      dpk: deskPublic,
      ppk: _phonePublic!,
    );
  }

  Map<String, dynamic> helloWire() {
    if (!isPhone) throw StateError('desk does not send hello');
    _derive();
    return {'t': 'hello', 'v': 1, 'ppk': b64url(_phonePublic!)};
  }

  Map<String, dynamic> sendEvent(Map<String, dynamic> event) {
    final material = keys;
    if (aborted || material == null) throw StateError('no session keys');
    final seq = ++_sendSeq;
    final direction = isPhone ? 1 : 2;
    final box = sealJson(
      key: direction == 1 ? material.kPd : material.kDp,
      sid: _sid,
      direction: direction,
      seq: seq,
      event: event,
    );
    return {'t': 'box', 'd': direction, 'seq': seq, 'c': b64url(box)};
  }

  void remember(int seq, Map<String, dynamic> wire) {
    _replies[seq] = wire;
  }

  GoRecv receive(Map<String, dynamic> wire) {
    if (aborted) return const GoRecv();
    if (wire['t'] == 'hello') return _hello(wire);
    if (wire['t'] == 'box') return _box(wire);
    return const GoRecv();
  }

  GoRecv _hello(Map<String, dynamic> wire) {
    if (isPhone) return const GoRecv();
    if (wire['v'] != 1 || wire['ppk'] is! String) {
      aborted = true;
      abortReason = 'version';
      return const GoRecv();
    }
    late final Uint8List ppk;
    try {
      ppk = b64urlDecode(wire['ppk'] as String);
      decodeGoPublic(ppk);
    } catch (_) {
      aborted = true;
      abortReason = 'public key';
      return const GoRecv();
    }
    final locked = _phonePublic;
    if (locked != null) {
      if (!_eq(locked, ppk)) {
        aborted = true;
        abortReason = 'competing';
      }
      return const GoRecv();
    }
    _phonePublic = ppk;
    _derive();
    return const GoRecv(hello: true);
  }

  GoRecv _box(Map<String, dynamic> wire) {
    final material = keys;
    if (material == null) return const GoRecv();
    final direction = _asInt(wire['d']);
    final seq = _asInt(wire['seq']);
    final c = wire['c'];
    final peer = isPhone ? 2 : 1;
    if (direction == null || seq == null || c is! String || direction != peer) {
      aborted = true;
      abortReason = 'malformed';
      return const GoRecv();
    }
    late final Map<String, dynamic> event;
    try {
      event = openJson(
        key: direction == 1 ? material.kPd : material.kDp,
        sid: _sid,
        direction: direction,
        seq: seq,
        box: b64urlDecode(c),
      );
    } catch (_) {
      aborted = true;
      abortReason = 'tamper';
      return const GoRecv();
    }
    if (seq <= _recvSeq) {
      final again = _replies[seq];
      return GoRecv(resend: again == null ? const [] : [again]);
    }
    _recvSeq = seq;
    return GoRecv(event: event, seq: seq);
  }
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  return null;
}

class GoGrant {
  final bool whole;
  final List<String> ids;
  final String mode;
  final int exp;

  const GoGrant({
    required this.whole,
    required this.ids,
    required this.mode,
    required this.exp,
  });

  bool get allowsComputerSend => mode == 'send' || mode == 'both';
  bool get allowsComputerReceive => mode == 'receive' || mode == 'both';

  bool canPull(String id) => allowsComputerReceive && (whole || ids.contains(id));
}

/// Null when the grant is missing a scope, a mode, an expiry, or (for
/// item scope) at least one id. The computer only receives what this allows.
GoGrant? parseGrant(Map<String, dynamic> event) {
  if (event['t'] != 'grant') return null;
  final scope = event['scope'];
  final mode = event['mode'];
  final exp = _asInt(event['exp']);
  if ((scope != 'items' && scope != 'all') || exp == null || exp <= 0) {
    return null;
  }
  if (mode != 'send' && mode != 'receive' && mode != 'both') return null;
  final ids = <String>[];
  if (scope == 'items') {
    final raw = event['ids'];
    if (raw is! List || raw.isEmpty) return null;
    for (final id in raw) {
      if (id is! String || id.isEmpty) return null;
      ids.add(id);
    }
  }
  return GoGrant(whole: scope == 'all', ids: ids, mode: mode, exp: exp);
}

bool sessionOver({
  required int nowSec,
  required int exp,
  required int lastInputSec,
  required int idleSec,
}) {
  return nowSec >= exp || nowSec - lastInputSec >= idleSec;
}

/// The real code plus two decoys, shuffled. [rng] is injected so tests don't
/// depend on a clock.
List<int> matchChoices(int real, Random rng) {
  final codes = <int>{real % 100};
  while (codes.length < 3) {
    codes.add(rng.nextInt(100));
  }
  return codes.toList()..shuffle(rng);
}

String twoDigits(int n) => (n % 100).toString().padLeft(2, '0');
