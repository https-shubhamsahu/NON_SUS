import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/crypto/device_keys.dart';
import '../../../core/crypto/nosus_seal.dart';
import 'drop_manifest.dart';

class DropFailure implements Exception {
  final String message;
  const DropFailure(this.message);

  @override
  String toString() => message;
}

class DropItem {
  final String id;
  final String state;
  final int sizeBytes;
  final DateTime createdAt;
  final DateTime expiresAt;

  const DropItem({
    required this.id,
    required this.state,
    required this.sizeBytes,
    required this.createdAt,
    required this.expiresAt,
  });

  factory DropItem.fromRow(Map<String, dynamic> row) => DropItem(
        id: row['id'] as String,
        state: row['state'] as String? ?? 'pending',
        sizeBytes: (row['size_bytes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(row['expires_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class DoorStatus {
  final DateTime? openUntil;
  final bool hasCode;

  const DoorStatus({this.openUntil, this.hasCode = false});

  bool get isOpen => openUntil != null && openUntil!.isAfter(DateTime.now());
}

/// Address, door, and inbox. The only place in the app that talks to the
/// drop tables and functions.
class DropRepository {
  DropRepository({this.client, this.httpClient});

  /// Defaults to the app's Supabase client and a fresh http client.
  final SupabaseClient? client;
  final http.Client? httpClient;

  SupabaseClient get _c => client ?? Supabase.instance.client;

  String? get _uid => _c.auth.currentUser?.id;

  Future<String?> myHandle() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _c.from('address_handles').select('handle').eq('user_id', uid).maybeSingle();
    return row?['handle'] as String?;
  }

  Future<String> claimHandle(String raw) async {
    final handle = AddressHandle.normalize(raw);
    final problem = AddressHandle.problem(handle);
    if (problem != null) throw DropFailure(problem);
    try {
      final claimed = await _c.rpc('claim_address_handle', params: {'p_handle': handle});
      return claimed as String;
    } on PostgrestException catch (e) {
      throw DropFailure(friendly(e));
    }
  }

  Future<void> releaseHandle() async {
    await _c.rpc('release_address_handle');
  }

  Future<DoorStatus> door() async {
    final uid = _uid;
    if (uid == null) return const DoorStatus();
    final row = await _c.from('drop_doors').select('open_until, code_hash').eq('user_id', uid).maybeSingle();
    if (row == null) return const DoorStatus();
    return DoorStatus(
      openUntil: DateTime.tryParse(row['open_until'] as String? ?? '')?.toLocal(),
      hasCode: row['code_hash'] != null,
    );
  }

  /// [minutes] 0 closes the door.
  Future<DoorStatus> setDoor(int minutes, {String? code}) async {
    try {
      final until = await _c.rpc('set_drop_door', params: {
        'p_open_minutes': minutes,
        'p_code': (code == null || code.isEmpty) ? null : code,
      });
      return DoorStatus(
        openUntil: until is String ? DateTime.tryParse(until)?.toLocal() : null,
        hasCode: minutes > 0 && code != null && code.isNotEmpty,
      );
    } on PostgrestException catch (e) {
      throw DropFailure(friendly(e));
    }
  }

  /// This account's live device public keys, for the door check code.
  Future<List<Uint8List>> liveDeviceKeys() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('device_keys')
        .select('public_key')
        .eq('user_id', uid)
        .isFilter('revoked_at', null);
    return [
      for (final row in rows)
        if (row['public_key'] is String) b64urlDecode(row['public_key'] as String),
    ];
  }

  /// Pending and accepted drops, live. RLS limits rows to this account and
  /// to those two states; the filter repeats it so a stale row that just
  /// moved to 'declined' drops out of the list.
  Stream<List<DropItem>> watchInbox() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _c
        .from('drops')
        .stream(primaryKey: ['id'])
        .eq('owner_user_id', uid)
        .order('created_at', ascending: false)
        .map((rows) => [
              for (final row in rows)
                if (row['state'] == 'pending' || row['state'] == 'accepted') DropItem.fromRow(row),
            ]);
  }

  /// drop id → sealed manifest, for the envelopes addressed to [deviceKeyId].
  Future<Map<String, String>> envelopes(List<String> dropIds, String deviceKeyId) async {
    if (dropIds.isEmpty) return const {};
    final rows = await _c
        .from('drop_envelopes')
        .select('drop_id, box')
        .eq('device_key_id', deviceKeyId)
        .inFilter('drop_id', dropIds);
    return {
      for (final row in rows) row['drop_id'] as String: row['box'] as String,
    };
  }

  static Future<DropManifest> openManifest(String dropId, String box) async {
    final plain = await DeviceKeys.instance.open(b64urlDecode(box), dropContext(dropId));
    return DropManifest.parse(plain);
  }

  /// Downloads the ciphertext and opens it on a background isolate.
  Future<Uint8List> fetchFile(String dropId, DropManifest manifest) async {
    Object? data;
    try {
      data = (await _c.functions.invoke('drop-fetch', body: {'dropId': dropId})).data;
    } on FunctionException {
      throw const DropFailure('This file is gone.');
    }
    final url = data is Map ? data['url'] : null;
    if (url is! String) throw const DropFailure('This file is gone.');
    final web = httpClient ?? http.Client();
    try {
      final file = await web.get(Uri.parse(url));
      if (file.statusCode != 200) throw const DropFailure('Couldn’t download it. Try again.');
      if (file.bodyBytes.length != manifest.size + 28) {
        throw const DropFailure('The file doesn’t match what was sent.');
      }
      return await compute(openDropFile, (
        key: manifest.fileKey,
        dropId: dropId,
        box: file.bodyBytes,
        size: manifest.size,
      ));
    } on DropFailure {
      rethrow;
    } catch (_) {
      throw const DropFailure('Couldn’t open this file on this phone.');
    } finally {
      if (httpClient == null) web.close();
    }
  }

  Future<void> accept(String dropId) => _rpc('accept_drop', dropId);
  Future<void> decline(String dropId) => _rpc('decline_drop', dropId);
  Future<void> block(String dropId) => _rpc('block_drop_sender', dropId);

  Future<int> blockCount() async => (await _c.rpc('count_drop_blocks') as num?)?.toInt() ?? 0;

  Future<void> clearBlocks() => _c.rpc('clear_drop_blocks');

  Future<void> _rpc(String name, String dropId) async {
    try {
      await _c.rpc(name, params: {'p_drop_id': dropId});
    } on PostgrestException catch (e) {
      throw DropFailure(friendly(e));
    }
  }

  static String friendly(PostgrestException e) {
    final m = e.message;
    if (m.contains('taken')) return 'That address is taken.';
    if (m.contains('bad handle')) return 'Use 4–20 letters, numbers, or hyphens.';
    if (m.contains('too many changes')) return 'You’ve changed your address a lot this month. Try later.';
    if (m.contains('no device key')) return 'This phone’s key isn’t set up, so the door stays closed.';
    if (m.contains('no address')) return 'Pick an address first.';
    if (m.contains('bad code')) return 'A door code is 4 to 8 digits.';
    if (m.contains('too long')) return 'A door opens for 24 hours at most.';
    if (m.contains('drop unavailable')) return 'This drop is gone.';
    if (m.contains('not enabled')) return 'Your address isn’t turned on for this account yet.';
    return 'Something went wrong. Try again.';
  }
}
