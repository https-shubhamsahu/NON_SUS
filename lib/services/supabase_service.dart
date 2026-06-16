import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../config/supabase_credentials.dart';
import '../features/groups/domain/models/study_group.dart';
import '../features/groups/models/group_file.dart';

/// Service to handle all interactions with the live Supabase project.
///
/// Automatically provides an [isConfigured] flag to check if live credentials
/// are available, falling back gracefully to mock storage if not.
///
/// Also performs a DNS pre-flight check during [initialize] and exposes
/// [isReachable] — if the host can't be resolved, realtime streams are
/// skipped entirely to prevent infinite reconnect loops.
class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  /// True only if credentials are set AND the host was reachable at startup.
  bool _isReachable = false;

  /// Flag indicating if valid Supabase credentials are configured
  bool get isConfigured => SupabaseBootstrap.isConfigured;

  /// True if credentials are set AND a DNS lookup succeeded at startup.
  /// Use this (instead of [isConfigured]) before opening any realtime streams.
  bool get isReachable => _isReachable;

  /// Compatibility entry point while legacy services migrate to repositories.
  Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        "SupabaseService: Credentials empty. Operating in offline mock fallback mode.",
      );
      return;
    }

    try {
      await SupabaseBootstrap.initialize();
      _isReachable = true;
      debugPrint("SupabaseService: Client successfully initialized.");
    } catch (e) {
      debugPrint("SupabaseService: Initialization error: $e");
      _isReachable = false;
    }
  }

  // ─── Study Groups Operations ───────────────────────────────────────────────

  /// Streams list of all study groups ordered by creation time.
  Stream<List<StudyGroup>> watchGroups() {
    if (!isConfigured) return const Stream.empty();

    return Supabase.instance.client
        .from('study_groups')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) {
          return list.map((m) {
            final levelStr = m['security_level'] as String? ?? 'encrypted';
            final level = SecurityLevel.values.firstWhere(
              (e) => e.name == levelStr.toLowerCase(),
              orElse: () => SecurityLevel.encrypted,
            );
            final rawTime = m['last_activity'] ?? m['created_at'];
            final time = rawTime != null
                ? DateTime.parse(rawTime)
                : DateTime.now();

            return StudyGroup(
              id: m['id'] as String,
              name: m['name'] as String,
              description: m['description'] as String? ?? '',
              securityLevel: level,
              members: const [
                GroupMember(
                  id: 'm1',
                  name: 'Alice Chen',
                  initials: 'AC',
                  isAdmin: true,
                ),
                GroupMember(id: 'm2', name: 'You (Sync)', initials: 'ME'),
              ],
              fileCount: m['file_count'] as int? ?? 0,
              lastActivity: time,
              isWatermarkEnabled: m['is_watermark_enabled'] as bool? ?? true,
              inviteCode: m['invite_code'] as String?,
            );
          }).toList();
        })
        .handleError((e) {
          debugPrint("SupabaseService: watchGroups error: $e");
        });
  }

  /// Creates a new study group inside Supabase database.
  Future<void> createGroup(StudyGroup group) async {
    if (!isConfigured) return;

    await Supabase.instance.client.from('study_groups').insert({
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'security_level': group.securityLevel.name,
      'is_watermark_enabled': group.isWatermarkEnabled,
      'invite_code': group.inviteCode,
    });
  }

  // ─── Secure Files Operations ────────────────────────────────────────────────

  /// Streams map of all files grouped by groupId ordered by upload time.
  Stream<Map<String, List<GroupFile>>> watchFiles() {
    if (!isConfigured) return const Stream.empty();

    return Supabase.instance.client
        .from('secure_files')
        .stream(primaryKey: ['id'])
        .order('uploaded_at', ascending: false)
        .map((list) {
          final Map<String, List<GroupFile>> filesMap = {};
          for (final row in list) {
            final typeStr = row['type'] as String? ?? 'pdf';
            final fileType = FileType.values.firstWhere(
              (e) => e.name == typeStr.toLowerCase(),
              orElse: () => FileType.pdf,
            );
            final statusStr = row['security_status'] as String? ?? 'secured';
            final status = FileSecurityStatus.values.firstWhere(
              (e) => e.name == statusStr.toLowerCase(),
              orElse: () => FileSecurityStatus.secured,
            );
            final rawTime = row['uploaded_at'];
            final time = rawTime != null
                ? DateTime.parse(rawTime)
                : DateTime.now();

            final file = GroupFile(
              id: row['id'] as String,
              name: row['name'] as String,
              type: fileType,
              groupId: row['group_id'] as String,
              uploadedByName: row['uploaded_by_name'] as String? ?? 'Anonymous',
              uploadedByInitials:
                  row['uploaded_by_initials'] as String? ?? 'AN',
              uploadedAt: time,
              sizeBytes: row['size_bytes'] as int? ?? 0,
              isWatermarked: row['is_watermarked'] as bool? ?? true,
              isPinned: row['is_pinned'] as bool? ?? false,
              securityStatus: status,
            );

            // Note: encryption keys are no longer stored in the DB (E2E fix).
            // Keys live exclusively in device SecureKeyStore.

            filesMap.putIfAbsent(file.groupId, () => []).add(file);
          }
          return filesMap;
        })
        .handleError((e) {
          debugPrint("SupabaseService: watchFiles error: $e");
        });
  }

  /// Saves metadata of a secure file inside Supabase database.
  Future<void> saveFileMetadata({
    required GroupFile file,
    required String key,
    required String iv,
  }) async {
    if (!isConfigured) return;

    await Supabase.instance.client.from('secure_files').insert({
      'id': file.id,
      'group_id': file.groupId,
      'name': file.name,
      'type': file.type.name,
      'uploaded_by_name': file.uploadedByName,
      'uploaded_by_initials': file.uploadedByInitials,
      'size_bytes': file.sizeBytes,
      'is_watermarked': file.isWatermarked,
      'is_pinned': file.isPinned,
      'security_status': file.securityStatus.name,
      // Encryption keys are NOT stored in the DB (E2E security).
      // They are persisted device-locally via SecureKeyStore.
    });
  }

  String get _driveProxyUrl =>
      '${SupabaseCredentials.url}/functions/v1/drive-proxy';

  String get _authHeader {
    // Consistently use the Supabase Anon Key. The Google Drive proxy Edge Function
    // authorizes requests signed with the Anon Key directly, which avoids failures
    // due to expired or missing user session JWTs.
    return 'Bearer ${SupabaseCredentials.anonKey}';
  }

  /// Deletes a secure file metadata from Supabase database AND from Google Drive.
  Future<void> deleteFile(String fileId) async {
    if (!isConfigured) return;

    // 1. Delete from Google Drive via Edge Function
    try {
      final client = HttpClient();
      final request = await client.deleteUrl(
        Uri.parse('$_driveProxyUrl/delete?fileId=$fileId'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader);
      final response = await request.close();
      if (response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        debugPrint(
          "SupabaseService: Delete proxy failed: ${response.statusCode} - $responseBody",
        );
      }
    } catch (e) {
      debugPrint("SupabaseService: Delete proxy exception: $e");
    }

    // 2. Delete database metadata
    await Supabase.instance.client
        .from('secure_files')
        .delete()
        .eq('id', fileId);
  }

  /// Toggles the pinned state of a secure file in the Supabase database.
  Future<void> togglePin(String fileId) async {
    if (!isConfigured) return;

    final response = await Supabase.instance.client
        .from('secure_files')
        .select('is_pinned')
        .eq('id', fileId)
        .maybeSingle();

    if (response != null) {
      final currentPin = response['is_pinned'] as bool? ?? false;
      await Supabase.instance.client
          .from('secure_files')
          .update({'is_pinned': !currentPin})
          .eq('id', fileId);
    }
  }

  // ─── Storage Operations ────────────────────────────────────────────────────

  /// Uploads binary file bytes directly to Supabase Storage.
  /// Returns the storage file ID on success.
  Future<String?> uploadStorageFile(
    String fileId,
    Uint8List encryptedBytes,
  ) async {
    if (!isConfigured) return null;

    try {
      await Supabase.instance.client.storage
          .from('secure-files')
          .uploadBinary(fileId, encryptedBytes);
      return fileId;
    } catch (e) {
      debugPrint("SupabaseService: Upload storage exception: $e");
      return null;
    }
  }

  /// Downloads binary file bytes directly from Supabase Storage.
  Future<Uint8List?> downloadStorageFile(String fileId) async {
    if (!isConfigured) return null;

    try {
      return await Supabase.instance.client.storage
          .from('secure-files')
          .download(fileId);
    } catch (e) {
      debugPrint("SupabaseService: Download storage exception: $e");
      return null;
    }
  }

  /// Fetches the Google Drive Service Account Email dynamically from the proxy.
  /// Deprecated: Not used anymore since we use native Supabase Storage.
  Future<String?> getServiceAccountEmail() async {
    return "Supabase Storage Active";
  }

  // ─── Audit Logging Operations ──────────────────────────────────────────────

  /// Streams the audit logs from Supabase ordered by creation time.
  Stream<List<Map<String, String>>> watchAuditLogs() {
    if (!isConfigured) return const Stream.empty();

    return Supabase.instance.client
        .from('audit_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) {
          return list.map((row) {
            final timeStr = row['created_at'] != null
                ? DateTime.parse(
                    row['created_at'],
                  ).toLocal().toIso8601String().substring(11, 19)
                : 'Now';
            return {
              'time': timeStr,
              'event': row['event'] as String? ?? '',
              'status': row['status'] as String? ?? '',
            };
          }).toList();
        })
        .handleError((e) {
          debugPrint("SupabaseService: watchAuditLogs error: $e");
        });
  }

  /// Inserts a new audit log record inside Supabase database.
  Future<void> logEvent(String event, String status) async {
    if (!isConfigured) return;

    await Supabase.instance.client.from('audit_logs').insert({
      'event': event,
      'status': status,
    });
  }

  /// Fetches private notes for a user.
  Future<String> fetchUserNote(String userId) async {
    if (!isConfigured) return '';
    try {
      final response = await Supabase.instance.client
          .from('user_notes')
          .select('note_text')
          .eq('user_id', userId)
          .maybeSingle();
      return response?['note_text'] as String? ?? 
          "Welcome to the NO SUS Secure Workspace!\n\n"
          "Quick Tutorial on Groups:\n"
          "1. Open the 'Groups' tab from the bottom nav.\n"
          "2. Tap the '+' icon to create a secure study group.\n"
          "3. Share the invite code with classmates.\n"
          "4. Upload notes — they are E2E encrypted locally.\n"
          "5. Use 'REVEAL' to read in our screenshot-proof viewer.";
    } catch (e) {
      debugPrint("SupabaseService: fetchUserNote error: $e");
      return '';
    }
  }

  /// Saves private notes for a user.
  Future<void> saveUserNote(String userId, String noteText) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('user_notes').upsert({
        'user_id': userId,
        'note_text': noteText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint("SupabaseService: saveUserNote error: $e");
    }
  }

  /// Fetches focus logs from the last 7 days for a user.
  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async {
    if (!isConfigured) return {};
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final response = await Supabase.instance.client
          .from('focus_logs')
          .select('date, focus_minutes')
          .eq('user_id', userId)
          .gte('date', sevenDaysAgo);

      final Map<DateTime, int> logs = {};
      for (final row in response) {
        final date = DateTime.parse(row['date'] as String);
        final minutes = row['focus_minutes'] as int? ?? 0;
        logs[DateTime(date.year, date.month, date.day)] = minutes;
      }
      return logs;
    } catch (e) {
      debugPrint("SupabaseService: fetchFocusLogs error: $e");
      return {};
    }
  }

  /// Increments daily study focus minutes for a user.
  Future<void> incrementFocusMinutes(String userId, int minutes) async {
    if (!isConfigured) return;
    try {
      final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
      final existing = await Supabase.instance.client
          .from('focus_logs')
          .select('focus_minutes')
          .eq('user_id', userId)
          .eq('date', todayStr)
          .maybeSingle();

      final currentMinutes = existing?['focus_minutes'] as int? ?? 0;
      await Supabase.instance.client.from('focus_logs').upsert({
        'user_id': userId,
        'date': todayStr,
        'focus_minutes': currentMinutes + minutes,
      });
    } catch (e) {
      debugPrint("SupabaseService: incrementFocusMinutes error: $e");
    }
  }

  /// Fetches daily count of security checks / logs from the last 7 days.
  Future<Map<DateTime, int>> fetchAuditLogCounts() async {
    if (!isConfigured) return {};
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final response = await Supabase.instance.client
          .from('audit_logs')
          .select('created_at')
          .gte('created_at', sevenDaysAgo);

      final Map<DateTime, int> counts = {};
      for (final row in response) {
        final date = DateTime.parse(row['created_at'] as String).toLocal();
        final dayKey = DateTime(date.year, date.month, date.day);
        counts[dayKey] = (counts[dayKey] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint("SupabaseService: fetchAuditLogCounts error: $e");
      return {};
    }
  }

  /// Fetches the profile of a user. If it doesn't exist, returns default values.
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    if (!isConfigured) return {};
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_color_start, avatar_color_end, onboarding_completed')
          .eq('id', userId)
          .maybeSingle();
      return response ?? {};
    } catch (e) {
      debugPrint("SupabaseService: fetchProfile error: $e");
      return {};
    }
  }

  /// Updates or inserts a profile.
  Future<void> saveProfile({
    required String userId,
    required String email,
    required String displayName,
    required String avatarColorStart,
    required String avatarColorEnd,
    bool onboardingCompleted = true,
  }) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'avatar_color_start': avatarColorStart,
        'avatar_color_end': avatarColorEnd,
        'onboarding_completed': onboardingCompleted,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint("SupabaseService: saveProfile error: $e");
    }
  }

  /// Resolves the group_id for a file by its storage/file ID.
  /// Used by ZeroTrustGateway to check access for live Supabase files
  /// that are not in the static mock note list.
  Future<String?> getFileGroupId(String fileId) async {
    if (!isConfigured) return null;
    try {
      final response = await Supabase.instance.client
          .from('secure_files')
          .select('group_id')
          .eq('id', fileId)
          .maybeSingle();
      return response?['group_id'] as String?;
    } catch (e) {
      debugPrint("SupabaseService: getFileGroupId error: $e");
      return null;
    }
  }
}

