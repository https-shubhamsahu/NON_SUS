import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `group_messages`, still sealed.
class GroupDropRow {
  final String id;
  final String groupId;
  final int epoch;
  final String senderId;
  final String kind;
  final String body;
  final String? attachmentPath;
  final DateTime createdAt;

  const GroupDropRow({
    required this.id,
    required this.groupId,
    required this.epoch,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.attachmentPath,
    required this.createdAt,
  });

  bool get isFile => kind == 'file';

  static GroupDropRow? fromRow(Map<String, dynamic> row) {
    try {
      return GroupDropRow(
        id: row['id'] as String,
        groupId: row['group_id'] as String,
        epoch: (row['epoch'] as num).toInt(),
        senderId: row['sender_user_id'] as String,
        kind: row['kind'] as String,
        body: row['body'] as String,
        attachmentPath: row['attachment_path'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The relay for Group drops: ciphertext rows and ciphertext objects.
class GroupDropsRepository {
  GroupDropsRepository(this._client);

  final SupabaseClient _client;

  static const bucket = 'group-drops';
  static const _window = 300;

  /// Newest [_window] messages, oldest first, live.
  Stream<List<GroupDropRow>> watch(String groupId) {
    return _client
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(_window)
        .map((rows) {
      final out = <GroupDropRow>[
        for (final r in rows) ?GroupDropRow.fromRow(r),
      ];
      out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return out;
    });
  }

  /// Fires when an envelope for one of this account's devices changes, so a
  /// waiting device can retry without polling. RLS limits rows to our own.
  Stream<void> envelopeChanges(String groupId) {
    return _client
        .from('group_key_envelopes')
        .stream(primaryKey: ['group_id', 'epoch', 'device_key_id'])
        .eq('group_id', groupId)
        .map((_) {});
  }

  Future<void> insert({
    required String id,
    required String groupId,
    required int epoch,
    required String kind,
    required String body,
    String? attachmentPath,
  }) async {
    await _client.from('group_messages').insert({
      'id': id,
      'group_id': groupId,
      'epoch': epoch,
      'kind': kind,
      'body': body,
      'attachment_path': attachmentPath,
    });
  }

  Future<void> upload(String path, Uint8List sealed) async {
    await _client.storage.from(bucket).uploadBinary(
          path,
          sealed,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            upsert: false,
          ),
        );
  }

  Future<Uint8List> download(String path) => _client.storage.from(bucket).download(path);

  Future<void> delete(GroupDropRow row) async {
    await _client.from('group_messages').delete().eq('id', row.id);
    final path = row.attachmentPath;
    if (path != null) {
      try {
        await _client.storage.from(bucket).remove([path]);
      } catch (_) {
        // The 7-day sweep removes it anyway.
      }
    }
  }
}
