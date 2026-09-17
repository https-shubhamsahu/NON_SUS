import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes a Play UGC report. The table is insert-only for signed-in users;
/// there is no SELECT policy, so the client cannot read reports back.
class ContentReportClient {
  ContentReportClient._();
  static final ContentReportClient instance = ContentReportClient._();

  static const kinds = {'file', 'member', 'group', 'other'};
  static const reasons = {
    'spam',
    'harassment',
    'inappropriate',
    'illegal',
    'other',
  };

  Future<void> submit({
    required String targetKind,
    required String targetId,
    String? groupId,
    required String reason,
    String? details,
  }) async {
    if (!kinds.contains(targetKind)) {
      throw ArgumentError.value(targetKind, 'targetKind');
    }
    if (!reasons.contains(reason)) {
      throw ArgumentError.value(reason, 'reason');
    }
    final trimmedId = targetId.trim();
    if (trimmedId.isEmpty || trimmedId.length > 128) {
      throw ArgumentError.value(targetId, 'targetId');
    }
    final trimmedDetails = details?.trim();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in to send a report.');
    }

    try {
      await Supabase.instance.client.from('content_reports').insert({
        'reporter_id': userId,
        'target_kind': targetKind,
        'target_id': trimmedId,
        'group_id': groupId,
        'reason': reason,
        if (trimmedDetails != null && trimmedDetails.isNotEmpty)
          'details': trimmedDetails,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ContentReportDuplicateException();
      }
      rethrow;
    }
  }
}

class ContentReportDuplicateException implements Exception {
  const ContentReportDuplicateException();

  @override
  String toString() => 'You already reported this today.';
}
