import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/core/crypto/device_keys.dart';
import 'package:no_sus/core/crypto/nosus_seal.dart';
import 'package:no_sus/features/groups/drops/group_drop_crypto.dart';
import 'package:no_sus/features/groups/drops/group_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory relay with the same rules as the migration's RLS and RPCs:
/// members only, envelopes readable only by their device's owner, puts only
/// for live devices of current members and only at the current epoch.
class FakeRelay {
  final Map<String, Set<String>> members = {};
  final Map<String, MemberDeviceKey> devices = {};
  final Set<String> revoked = {};
  final Map<String, int> epochs = {};
  final Map<String, Uint8List> envelopes = {};

  String _k(String g, int e, String d) => '$g|$e|$d';

  bool isMember(String g, String u) => members[g]?.contains(u) ?? false;

  Iterable<MemberDeviceKey> liveMemberDevices(String g) => devices.values
      .where((d) => !revoked.contains(d.deviceKeyId) && isMember(g, d.userId));

  bool hasEnvelope(String g, int e, String deviceKeyId) => envelopes.containsKey(_k(g, e, deviceKeyId));
}

class FakeApi implements GroupKeyApi {
  FakeApi(this.relay, this.userId);
  final FakeRelay relay;
  final String userId;

  void _member(String g) {
    if (!relay.isMember(g, userId)) throw StateError('not a member');
  }

  @override
  Future<int?> currentEpoch(String groupId) async =>
      relay.isMember(groupId, userId) ? relay.epochs[groupId] : null;

  @override
  Future<int?> startEpoch(String groupId, {int? expectedCurrent}) async {
    _member(groupId);
    final cur = relay.epochs[groupId] ?? 0;
    if (expectedCurrent != null && cur != expectedCurrent) return null;
    return relay.epochs[groupId] = cur + 1;
  }

  @override
  Future<Uint8List?> ownEnvelope(String groupId, int epoch, String deviceKeyId) async {
    if (!relay.isMember(groupId, userId)) return null;
    if (relay.devices[deviceKeyId]?.userId != userId) return null;
    return relay.envelopes[relay._k(groupId, epoch, deviceKeyId)];
  }

  @override
  Future<void> dropOwnEnvelope(String groupId, int epoch, String deviceKeyId) async {
    if (relay.devices[deviceKeyId]?.userId != userId) return;
    relay.envelopes.remove(relay._k(groupId, epoch, deviceKeyId));
  }

  @override
  Future<List<MemberDeviceKey>> memberDeviceKeys(String groupId) async {
    _member(groupId);
    return relay.liveMemberDevices(groupId).toList();
  }

  @override
  Future<List<MemberDeviceKey>> devicesMissingEnvelope(String groupId, int epoch) async {
    _member(groupId);
    return relay
        .liveMemberDevices(groupId)
        .where((d) => !relay.hasEnvelope(groupId, epoch, d.deviceKeyId))
        .toList();
  }

  @override
  Future<int> putEnvelopes(String groupId, int epoch, Map<String, Uint8List> boxes) async {
    _member(groupId);
    if (relay.epochs[groupId] != epoch) throw StateError('stale epoch');
    final allowed = relay.liveMemberDevices(groupId).map((d) => d.deviceKeyId).toSet();
    var n = 0;
    for (final e in boxes.entries) {
      if (!allowed.contains(e.key)) continue;
      final k = relay._k(groupId, epoch, e.key);
      if (relay.envelopes.containsKey(k)) continue;
      relay.envelopes[k] = e.value;
      n++;
    }
    return n;
  }

  @override
  Future<bool> needsRotation(String groupId) async {
    if (!relay.isMember(groupId, userId)) return false;
    final e = relay.epochs[groupId];
    if (e == null) return false;
    for (final key in relay.envelopes.keys) {
      final parts = key.split('|');
      if (parts[0] != groupId || int.parse(parts[1]) != e) continue;
      final d = relay.devices[parts[2]];
      if (d == null || relay.revoked.contains(d.deviceKeyId) || !relay.isMember(groupId, d.userId)) {
        return true;
      }
    }
    return false;
  }
}

class PairDevice implements GroupDevice {
  PairDevice(this.id, this.pair);
  final String id;
  final GoKeyPair pair;

  @override
  Future<String?> deviceKeyId() async => id;

  @override
  Future<Uint8List> open(Uint8List box, String context) async => openBox(
        recipientPrivate: pair.privateKey,
        recipientPublic: pair.publicKey,
        context: context,
        box: box,
      );
}

/// The app's real DeviceKeys path, on the software backend.
class SoftwareDevice implements GroupDevice {
  SoftwareDevice(this.id);
  final String id;

  @override
  Future<String?> deviceKeyId() async => id;

  @override
  Future<Uint8List> open(Uint8List box, String context) => DeviceKeys.instance.open(box, context);
}

class Member {
  Member(this.userId, this.deviceKeyId, this.device, FakeRelay relay)
      : service = GroupKeyService(api: FakeApi(relay, userId), device: device);
  final String userId;
  final String deviceKeyId;
  final GroupDevice device;
  final GroupKeyService service;
}

const g = 'g_1726000000000';

void main() {
  late FakeRelay relay;
  late Member alice;
  late Member bob;
  late Member carol;

  Member addMember(String userId, String deviceKeyId, GroupDevice device, Uint8List publicKey) {
    (relay.members[g] ??= {}).add(userId);
    relay.devices[deviceKeyId] = MemberDeviceKey(
      deviceKeyId: deviceKeyId,
      userId: userId,
      publicKey: publicKey,
      kind: 'software',
    );
    return Member(userId, deviceKeyId, device, relay);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceKeys.overrideForTest(SoftwareDeviceKeyBackend());
    relay = FakeRelay();
    final a = generateGoKeyPair();
    final b = generateGoKeyPair();
    alice = addMember('alice', 'dk-alice', PairDevice('dk-alice', a), a.publicKey);
    bob = addMember('bob', 'dk-bob', PairDevice('dk-bob', b), b.publicKey);
    carol = addMember(
      'carol',
      'dk-carol',
      SoftwareDevice('dk-carol'),
      await DeviceKeys.instance.publicKey(),
    );
  });

  test('first opener creates the key and all three members open it', () async {
    final a = await alice.service.prepare(g);
    expect(a, isA<GroupKeyReady>());
    a as GroupKeyReady;
    expect(a.epoch, 1);
    expect(relay.envelopes.length, 3);

    final b = await bob.service.prepare(g);
    final c = await carol.service.prepare(g);
    expect(b, isA<GroupKeyReady>());
    expect(c, isA<GroupKeyReady>());
    expect((b as GroupKeyReady).key, a.key);
    expect((c as GroupKeyReady).key, a.key);

    const id = '6f1c2a8e-3b1d-4c7e-9a55-0d2f4b6c8e10';
    final body = sealDropMessage(
      groupKey: a.key,
      groupId: g,
      epoch: a.epoch,
      messageId: id,
      payload: const DropPayload(text: 'from alice'),
    );
    for (final reader in [b, c]) {
      expect(
        openDropMessage(groupKey: reader.key, groupId: g, epoch: reader.epoch, messageId: id, body: body).text,
        'from alice',
      );
    }
  });

  test('an envelope for one device does not open on another', () async {
    await alice.service.prepare(g);
    final bobBox = relay.envelopes['$g|1|dk-bob']!;
    expect(
      () => alice.device.open(bobBox, groupKeyContext(g, 1)),
      throwsA(anything),
    );
    // Right device, wrong context (another group or epoch).
    expect(
      () => bob.device.open(bobBox, groupKeyContext(g, 2)),
      throwsA(anything),
    );
  });

  test('a device added later waits, then is let in by any member with the key', () async {
    await alice.service.prepare(g);
    final d = generateGoKeyPair();
    final dave = addMember('dave', 'dk-dave', PairDevice('dk-dave', d), d.publicKey);

    expect(await dave.service.prepare(g), isA<GroupKeyWaiting>());

    await bob.service.prepare(g); // heals
    final ready = await dave.service.prepare(g);
    expect(ready, isA<GroupKeyReady>());
    expect((ready as GroupKeyReady).key, alice.service.cachedKey(g, 1));
  });

  test('removal rotates to a key only remaining members get', () async {
    final first = await alice.service.prepare(g) as GroupKeyReady;
    await bob.service.prepare(g);
    await carol.service.prepare(g);

    relay.members[g]!.remove('carol'); // remove_group_member
    final epoch = await alice.service.rotateAfterRemoval(g);
    expect(epoch, 2);

    expect(relay.hasEnvelope(g, 2, 'dk-alice'), isTrue);
    expect(relay.hasEnvelope(g, 2, 'dk-bob'), isTrue);
    expect(relay.hasEnvelope(g, 2, 'dk-carol'), isFalse);

    final b = await bob.service.prepare(g) as GroupKeyReady;
    expect(b.epoch, 2);
    expect(b.key, isNot(first.key));
    expect(b.key, alice.service.cachedKey(g, 2));

    // Carol cannot get the new key, even with a fresh service and no cache.
    final carolAgain = GroupKeyService(api: FakeApi(relay, 'carol'), device: carol.device);
    expect(await carolAgain.keyFor(g, 2), isNull);
    expect(await carolAgain.keyFor(g, 1), isNull);

    // Remaining members still read the old epoch.
    final bobAgain = GroupKeyService(api: FakeApi(relay, 'bob'), device: bob.device);
    expect(await bobAgain.keyFor(g, 1), first.key);
  });

  test('someone leaving is caught by the next member to open the chat', () async {
    await alice.service.prepare(g);
    relay.members[g]!.remove('carol'); // left on their own; no admin rotated
    final b = await bob.service.prepare(g) as GroupKeyReady;
    expect(b.epoch, 2);
    expect(relay.hasEnvelope(g, 2, 'dk-carol'), isFalse);
    expect(await bob.service.prepare(g), isA<GroupKeyReady>());
    expect(relay.epochs[g], 2); // no second rotation
  });

  test('a revoked device triggers rotation and is left out', () async {
    await alice.service.prepare(g);
    relay.revoked.add('dk-bob');
    final a = await alice.service.prepare(g) as GroupKeyReady;
    expect(a.epoch, 2);
    expect(relay.hasEnvelope(g, 2, 'dk-bob'), isFalse);
  });

  test('two first openers agree on one key', () async {
    // Bob loses the compare-and-set race to Alice.
    await alice.service.prepare(g);
    final b = await bob.service.prepare(g) as GroupKeyReady;
    expect(relay.epochs[g], 1);
    expect(b.key, alice.service.cachedKey(g, 1));
  });

  test('a garbage envelope is dropped and healed', () async {
    await alice.service.prepare(g);
    relay.envelopes['$g|1|dk-bob'] = sealBox(
      recipientPublic: generateGoKeyPair().publicKey,
      context: groupKeyContext(g, 1),
      plain: randomBytes(32),
    );
    expect(await bob.service.prepare(g), isA<GroupKeyWaiting>());
    expect(relay.hasEnvelope(g, 1, 'dk-bob'), isFalse);
    await alice.service.prepare(g);
    expect(await bob.service.prepare(g), isA<GroupKeyReady>());
  });

  test('wrapGroupKey skips a malformed public key', () {
    final good = generateGoKeyPair();
    final boxes = wrapGroupKey(
      groupId: g,
      epoch: 1,
      key: randomBytes(32),
      devices: [
        MemberDeviceKey(deviceKeyId: 'ok', userId: 'u', publicKey: good.publicKey, kind: 'keystore'),
        MemberDeviceKey(deviceKeyId: 'bad', userId: 'u', publicKey: Uint8List(65), kind: 'web'),
      ],
    );
    expect(boxes.keys, ['ok']);
    expect(b64url(boxes['ok']!).length, 168); // matches the migration's CHECK
  });
}
