import 'dart:async';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show InvalidCipherTextException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/nosus_seal.dart';
import '../../../core/utils/debug_logger.dart';
import 'group_drop_crypto.dart';

/// One live device key of a group member, as the relay serves it.
class MemberDeviceKey {
  final String deviceKeyId;
  final String userId;
  final Uint8List publicKey;
  final String kind;

  const MemberDeviceKey({
    required this.deviceKeyId,
    required this.userId,
    required this.publicKey,
    required this.kind,
  });

  static MemberDeviceKey? fromRow(Map<String, dynamic> row) {
    try {
      final pub = b64urlDecode(row['public_key'] as String);
      decodeGoPublic(pub);
      return MemberDeviceKey(
        deviceKeyId: row['device_key_id'] as String,
        userId: row['user_id'] as String,
        publicKey: pub,
        kind: row['kind'] as String? ?? 'software',
      );
    } catch (_) {
      return null; // a malformed key is skipped, never sealed to
    }
  }
}

/// The relay side of key management. [SupabaseGroupKeyApi] in the app;
/// an in-memory fake in tests.
abstract class GroupKeyApi {
  Future<int?> currentEpoch(String groupId);

  /// New epoch = current + 1. With [expectedCurrent], returns null instead
  /// when someone else moved the epoch first.
  Future<int?> startEpoch(String groupId, {int? expectedCurrent});

  Future<Uint8List?> ownEnvelope(String groupId, int epoch, String deviceKeyId);
  Future<void> dropOwnEnvelope(String groupId, int epoch, String deviceKeyId);
  Future<List<MemberDeviceKey>> memberDeviceKeys(String groupId);
  Future<List<MemberDeviceKey>> devicesMissingEnvelope(String groupId, int epoch);

  /// deviceKeyId → sealed box. Returns how many were stored.
  Future<int> putEnvelopes(String groupId, int epoch, Map<String, Uint8List> boxes);
  Future<bool> needsRotation(String groupId);
}

/// This device, as far as group keys care.
abstract class GroupDevice {
  /// device_keys row id, registering on first use. Null when signed out.
  Future<String?> deviceKeyId();
  Future<Uint8List> open(Uint8List box, String context);
}

class DeviceKeysGroupDevice implements GroupDevice {
  @override
  Future<String?> deviceKeyId() => DeviceKeys.instance.ensureRegistered();

  @override
  Future<Uint8List> open(Uint8List box, String context) => DeviceKeys.instance.open(box, context);
}

sealed class GroupKeyState {
  const GroupKeyState();
}

class GroupKeyReady extends GroupKeyState {
  final int epoch;
  final Uint8List key;
  const GroupKeyReady(this.epoch, this.key);
}

/// The group has a key but no member has wrapped it for this device yet.
class GroupKeyWaiting extends GroupKeyState {
  final int epoch;
  const GroupKeyWaiting(this.epoch);
}

class GroupKeyNoDevice extends GroupKeyState {
  const GroupKeyNoDevice();
}

/// Seals [key] to every device in [devices]. Keys that fail to decode are
/// skipped.
Map<String, Uint8List> wrapGroupKey({
  required String groupId,
  required int epoch,
  required Uint8List key,
  required Iterable<MemberDeviceKey> devices,
}) {
  final out = <String, Uint8List>{};
  for (final d in devices) {
    try {
      out[d.deviceKeyId] = sealBox(
        recipientPublic: d.publicKey,
        context: groupKeyContext(groupId, epoch),
        plain: key,
      );
    } on FormatException {
      continue;
    }
  }
  return out;
}

/// Group keys for this device. Keys live in memory only, one per
/// (group, epoch), so older messages stay readable after a rotation.
class GroupKeyService {
  GroupKeyService({required this.api, required this.device});

  final GroupKeyApi api;
  final GroupDevice device;

  final Map<String, Map<int, Uint8List>> _keys = {};
  final Map<String, Future<GroupKeyState>> _inflight = {};

  Uint8List? cachedKey(String groupId, int epoch) => _keys[groupId]?[epoch];

  void forgetAll() => _keys.clear();

  /// Everything the CHAT tab needs before it can send: a current key,
  /// created if the group has none, rotated if a departed member or a
  /// revoked device still holds it, and wrapped for devices that lack it.
  Future<GroupKeyState> prepare(String groupId) {
    final running = _inflight[groupId];
    if (running != null) return running;
    // Block body on purpose: remove() returns this same future, and
    // whenComplete would wait on it forever.
    final future = _prepare(groupId).whenComplete(() {
      _inflight.remove(groupId);
    });
    _inflight[groupId] = future;
    return future;
  }

  Future<GroupKeyState> _prepare(String groupId) async {
    final me = await device.deviceKeyId();
    if (me == null) return const GroupKeyNoDevice();

    var epoch = await api.currentEpoch(groupId);
    if (epoch == null) {
      final created = await _startEpoch(groupId, expectedCurrent: 0);
      if (created != null) return created;
      epoch = await api.currentEpoch(groupId);
      if (epoch == null) throw StateError('group key epoch missing');
    }

    final key = await keyFor(groupId, epoch);
    if (key == null) return GroupKeyWaiting(epoch);

    if (await api.needsRotation(groupId)) {
      final rotated = await _startEpoch(groupId, expectedCurrent: epoch);
      if (rotated != null) return rotated;
      // Someone else rotated first. Use theirs.
      final latest = await api.currentEpoch(groupId);
      if (latest == null) throw StateError('group key epoch missing');
      final latestKey = await keyFor(groupId, latest);
      if (latestKey == null) return GroupKeyWaiting(latest);
      await heal(groupId, latest, latestKey);
      return GroupKeyReady(latest, latestKey);
    }

    await heal(groupId, epoch, key);
    return GroupKeyReady(epoch, key);
  }

  /// The key for [epoch], from memory or this device's envelope. Null when
  /// this device was never given that epoch (joined later, or removed).
  Future<Uint8List?> keyFor(String groupId, int epoch) async {
    final cached = cachedKey(groupId, epoch);
    if (cached != null) return cached;
    final me = await device.deviceKeyId();
    if (me == null) return null;
    final box = await api.ownEnvelope(groupId, epoch, me);
    if (box == null) return null;
    try {
      final key = await device.open(box, groupKeyContext(groupId, epoch));
      if (key.length != 32) throw const FormatException('group key');
      (_keys[groupId] ??= {})[epoch] = key;
      return key;
    } on Object catch (e) {
      // Only a box that authenticates wrong is dropped. A Keystore or
      // channel hiccup must not throw away a good envelope.
      if (e is! InvalidCipherTextException && e is! FormatException && e is! ArgumentError) {
        rethrow;
      }
      // Garbage, or a box sealed to an older key of this device. Drop it so
      // a member with the key can wrap it again.
      debugLog('GroupKeyService: envelope did not open: $e');
      try {
        await api.dropOwnEnvelope(groupId, epoch, me);
      } catch (_) {}
      return null;
    }
  }

  /// Wraps the current key for member devices that have no envelope yet.
  Future<int> heal(String groupId, int epoch, Uint8List key) async {
    final missing = await api.devicesMissingEnvelope(groupId, epoch);
    if (missing.isEmpty) return 0;
    final boxes = wrapGroupKey(groupId: groupId, epoch: epoch, key: key, devices: missing);
    if (boxes.isEmpty) return 0;
    return api.putEnvelopes(groupId, epoch, boxes);
  }

  /// After an admin removes or bans someone: a fresh key wrapped only for
  /// the members who remain. No-op when the group never used drops.
  Future<int?> rotateAfterRemoval(String groupId) async {
    final current = await api.currentEpoch(groupId);
    if (current == null) return null;
    final ready = await _startEpoch(groupId);
    return ready?.epoch;
  }

  Future<GroupKeyReady?> _startEpoch(String groupId, {int? expectedCurrent}) async {
    final key = randomBytes(32);
    final epoch = await api.startEpoch(groupId, expectedCurrent: expectedCurrent);
    if (epoch == null) return null;
    (_keys[groupId] ??= {})[epoch] = key;
    final devices = await api.memberDeviceKeys(groupId);
    final boxes = wrapGroupKey(groupId: groupId, epoch: epoch, key: key, devices: devices);
    if (boxes.isNotEmpty) await api.putEnvelopes(groupId, epoch, boxes);
    return GroupKeyReady(epoch, key);
  }
}

class SupabaseGroupKeyApi implements GroupKeyApi {
  SupabaseGroupKeyApi(this._client);

  final SupabaseClient _client;

  @override
  Future<int?> currentEpoch(String groupId) async {
    final res = await _client.rpc('group_key_current_epoch', params: {'p_group_id': groupId});
    return (res as num?)?.toInt();
  }

  @override
  Future<int?> startEpoch(String groupId, {int? expectedCurrent}) async {
    final res = await _client.rpc('start_group_key_epoch', params: {
      'p_group_id': groupId,
      'p_expected_current': expectedCurrent,
    });
    return (res as num?)?.toInt();
  }

  @override
  Future<Uint8List?> ownEnvelope(String groupId, int epoch, String deviceKeyId) async {
    final row = await _client
        .from('group_key_envelopes')
        .select('box')
        .eq('group_id', groupId)
        .eq('epoch', epoch)
        .eq('device_key_id', deviceKeyId)
        .maybeSingle();
    final box = row?['box'] as String?;
    return box == null ? null : b64urlDecode(box);
  }

  @override
  Future<void> dropOwnEnvelope(String groupId, int epoch, String deviceKeyId) async {
    await _client
        .from('group_key_envelopes')
        .delete()
        .eq('group_id', groupId)
        .eq('epoch', epoch)
        .eq('device_key_id', deviceKeyId);
  }

  @override
  Future<List<MemberDeviceKey>> memberDeviceKeys(String groupId) =>
      _devices('group_member_device_keys', {'p_group_id': groupId});

  @override
  Future<List<MemberDeviceKey>> devicesMissingEnvelope(String groupId, int epoch) =>
      _devices('group_key_devices_missing', {'p_group_id': groupId, 'p_epoch': epoch});

  Future<List<MemberDeviceKey>> _devices(String fn, Map<String, dynamic> params) async {
    final rows = await _client.rpc(fn, params: params);
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) ?MemberDeviceKey.fromRow(Map<String, dynamic>.from(row)),
    ];
  }

  @override
  Future<int> putEnvelopes(String groupId, int epoch, Map<String, Uint8List> boxes) async {
    final res = await _client.rpc('put_group_key_envelopes', params: {
      'p_group_id': groupId,
      'p_epoch': epoch,
      'p_envelopes': [
        for (final e in boxes.entries) {'device_key_id': e.key, 'box': b64url(e.value)},
      ],
    });
    return (res as num?)?.toInt() ?? 0;
  }

  @override
  Future<bool> needsRotation(String groupId) async {
    final res = await _client.rpc('group_key_needs_rotation', params: {'p_group_id': groupId});
    return res == true;
  }
}
