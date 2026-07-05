import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase/supabase_bootstrap.dart';
import '../config/supabase_credentials.dart';
import 'audit_service.dart';
import '../core/utils/debug_logger.dart';

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
      debugLog(
        "SupabaseService: Credentials empty. Operating in offline mock fallback mode.",
      );
      return;
    }

    try {
      await SupabaseBootstrap.initialize();
      _isReachable = true;
      debugLog("SupabaseService: Client successfully initialized.");
    } catch (e) {
      debugLog("SupabaseService: Initialization error: $e");
      _isReachable = false;
    }
  }

  // ─── Google Drive Proxy Operations ──────────────────────────────────────────
  
  String get _driveProxyUrl =>
      '${SupabaseCredentials.url}/functions/v1/drive-proxy';

  String get _authHeader {
    // Consistently use the Supabase Anon Key. The Google Drive proxy Edge Function
    // authorizes requests signed with the Anon Key directly, which avoids failures
    // due to expired or missing user session JWTs.
    return 'Bearer ${SupabaseCredentials.anonKey}';
  }

  /// Deletes a secure file from Google Drive via Edge Function.
  Future<void> deleteGDriveFile(String fileId) async {
    if (!isConfigured) return;

    try {
      final client = HttpClient();
      final request = await client.deleteUrl(
        Uri.parse('$_driveProxyUrl/delete?fileId=$fileId'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader);
      final response = await request.close();
      if (response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        debugLog(
          "SupabaseService: Delete proxy failed: ${response.statusCode} - $responseBody",
        );
      }
    } catch (e) {
      debugLog("SupabaseService: Delete proxy exception: $e");
    }
  }

  /// Downloads a file from the Google Drive proxy Edge Function.
  Future<Uint8List?> downloadGDriveFile(String fileId) async {
    if (!isConfigured) return null;

    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('$_driveProxyUrl/download?fileId=$fileId'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader);
      final response = await request.close();
      if (response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        debugLog(
          "SupabaseService: Download proxy failed: ${response.statusCode} - $responseBody",
        );
        return null;
      }

      final bytesBuilder = BytesBuilder();
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      return bytesBuilder.toBytes();
    } catch (e) {
      debugLog("SupabaseService: Download proxy exception: $e");
      return null;
    }
  }

  /// Fetches the Google Drive Service Account Email dynamically from the proxy.
  Future<String?> getServiceAccountEmail() async {
    if (!isConfigured) return null;

    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('$_driveProxyUrl/info'));
      request.headers.set(HttpHeaders.authorizationHeader, _authHeader);
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = json.decode(responseBody) as Map<String, dynamic>;
        return data['serviceAccountEmail'] as String?;
      } else {
        final responseBody = await response.transform(utf8.decoder).join();
        debugLog("SupabaseService: getServiceAccountEmail failed: ${response.statusCode} - $responseBody");
      }
    } catch (e) {
      debugLog("SupabaseService: getServiceAccountEmail exception: $e");
    }
    return null;
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
                    row['created_at'] as String,
                  ).toLocal().toIso8601String().substring(11, 19)
                : 'Now';
            final eventType = row['event_type'] as String? ?? 'group_updated';
            final metadata = row['metadata'] as Map<String, dynamic>? ?? {};

            return {
              'time': timeStr,
              'event': AuditService.formatEventDescription(eventType, metadata),
              'status': AuditService.getEventStatus(eventType, metadata),
            };
          }).toList();
        })
        .handleError((e) {
          debugLog("SupabaseService: watchAuditLogs error: $e");
        });
  }

  /// Inserts a new audit log record inside Supabase database via secure RPC.
  Future<void> logEvent(
    String eventType, {
    required String groupId,
    String? fileId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isConfigured) return;

    try {
      await Supabase.instance.client.rpc('log_group_event', params: {
        'p_group_id': groupId,
        'p_file_id': fileId,
        'p_event_type': eventType,
        'p_metadata': metadata ?? {},
      });
    } catch (e) {
      debugLog("SupabaseService: logEvent RPC failed: $e");
    }
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
          "4. Upload notes — they are stored securely in the workspace.\n"
          "5. Use 'REVEAL' to read in our screenshot-proof viewer.";
    } catch (e) {
      debugLog("SupabaseService: fetchUserNote error: $e");
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
      debugLog("SupabaseService: saveUserNote error: $e");
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
      debugLog("SupabaseService: fetchFocusLogs error: $e");
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
      debugLog("SupabaseService: incrementFocusMinutes error: $e");
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
      debugLog("SupabaseService: fetchAuditLogCounts error: $e");
      return {};
    }
  }

  /// Fetches the profile of a user. If it doesn't exist, returns default values.
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    if (!isConfigured) return {};
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_color_start, avatar_color_end, onboarding_completed, survey_goals, survey_features, survey_user_type')
          .eq('id', userId)
          .maybeSingle();
      return response ?? {};
    } catch (e) {
      debugLog("SupabaseService: fetchProfile error: $e");
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
      debugLog("SupabaseService: saveProfile error: $e");
    }
  }

  /// Updates only the survey data fields in the user's profile.
  Future<void> updateSurveyData({
    required String userId,
    required List<String> goals,
    required List<String> features,
    required String userType,
  }) async {
    if (!isConfigured) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'survey_goals': goals,
        'survey_features': features,
        'survey_user_type': userType,
      }).eq('id', userId);
    } catch (e) {
      debugLog("SupabaseService: updateSurveyData error: $e");
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
      debugLog("SupabaseService: getFileGroupId error: $e");
      return null;
    }
  }
}

