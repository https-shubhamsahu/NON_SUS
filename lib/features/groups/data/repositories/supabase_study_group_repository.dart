import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/study_group.dart';
import '../../domain/repositories/study_group_repository.dart';

class SupabaseStudyGroupRepository implements StudyGroupRepository {
  final SupabaseClient _client;

  const SupabaseStudyGroupRepository(this._client);

  @override
  Stream<List<StudyGroup>> watchGroups() {
    return _client
        .from('study_groups')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_mapGroup).toList(growable: false));
  }

  @override
  Future<void> createGroup(StudyGroup group) async {
    await _client.from('study_groups').insert({
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'security_level': group.securityLevel.name,
      'is_watermark_enabled': group.isWatermarkEnabled,
      'invite_code': group.inviteCode,
    });
  }

  StudyGroup _mapGroup(Map<String, dynamic> row) {
    return StudyGroup(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      securityLevel: _parseSecurityLevel(row['security_level']),
      members: const [],
      fileCount: row['file_count'] as int? ?? 0,
      lastActivity: _parseDate(row['last_activity'] ?? row['created_at']),
      isWatermarkEnabled: row['is_watermark_enabled'] as bool? ?? true,
      inviteCode: row['invite_code'] as String?,
    );
  }

  SecurityLevel _parseSecurityLevel(Object? value) {
    return SecurityLevel.values.firstWhere(
      (level) => level.name == value?.toString().toLowerCase(),
      orElse: () => SecurityLevel.encrypted,
    );
  }

  DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
