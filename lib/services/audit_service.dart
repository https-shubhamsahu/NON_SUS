import 'dart:async';
import 'supabase_service.dart';
import '../core/utils/debug_logger.dart';

class AuditService {
  static final AuditService instance = AuditService._internal();
  AuditService._internal();

  final List<Map<String, String>> _auditLogs = [
    {'time': 'Now', 'event': 'Workspace session initiated', 'status': 'INFO'},
  ];

  final StreamController<List<Map<String, String>>> _auditLogsStream =
      StreamController<List<Map<String, String>>>.broadcast();

  StreamSubscription? _auditLogsSub;

  void init() {
    _auditLogsSub?.cancel();
    _auditLogsSub = null;

    if (SupabaseService.instance.isReachable) {
      _auditLogsSub = SupabaseService.instance.watchAuditLogs().listen(
        (data) {
          _auditLogs.clear();
          _auditLogs.addAll(data);
          _auditLogsStream.add(_auditLogs);
        },
        onError: (e) {
          debugLog(
            "AuditService: watchAuditLogs stream error, offline fallback active. $e",
          );
        },
      );
    }
  }

  void logEvent(
    String eventTypeOrDescription,
    String statusOrInfo, {
    String? groupId,
    String? fileId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    final timeStr = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';

    if (SupabaseService.instance.isReachable) {
      final allowedEventTypes = [
        'file_uploaded',
        'file_downloaded',
        'file_viewed',
        'file_deleted',
        'file_renamed',
        'file_pinned',
        'member_joined',
        'member_left',
        'member_promoted',
        'member_demoted',
        'group_created',
        'group_updated',
        'invite_generated',
        'invite_used',
        'screenshot_attempt',
        'recording_attempt',
        'unauthorized_access',
      ];

      String eventType = eventTypeOrDescription;
      Map<String, dynamic> meta = metadata ?? {};
      if (!allowedEventTypes.contains(eventType)) {
        if (eventTypeOrDescription.contains('uploaded')) {
          eventType = 'file_uploaded';
          meta['file_name'] = _extractFileName(eventTypeOrDescription);
        } else if (eventTypeOrDescription.contains('Deleted') ||
            eventTypeOrDescription.contains('deleted')) {
          eventType = 'file_deleted';
          meta['file_id'] = fileId ?? _extractFileId(eventTypeOrDescription);
        } else if (eventTypeOrDescription.contains('Created') ||
            eventTypeOrDescription.contains('created')) {
          eventType = 'group_created';
          meta['group_name'] = _extractGroupName(eventTypeOrDescription);
        } else {
          eventType = 'group_updated';
          meta['description'] = eventTypeOrDescription;
        }
      }

      _auditLogs.insert(0, {
        'time': timeStr,
        'event': formatEventDescription(eventType, meta),
        'status': getEventStatus(eventType, meta),
      });
      _auditLogsStream.add(_auditLogs);

      SupabaseService.instance.logEvent(
        eventType,
        groupId: groupId ?? 'default_group',
        fileId: fileId,
        metadata: meta,
      );
      return;
    }

    final allowedEventTypes = [
      'file_uploaded',
      'file_downloaded',
      'file_viewed',
      'file_deleted',
      'file_renamed',
      'file_pinned',
      'member_joined',
      'member_left',
      'member_promoted',
      'member_demoted',
      'group_created',
      'group_updated',
      'invite_generated',
      'invite_used',
      'screenshot_attempt',
      'recording_attempt',
      'unauthorized_access',
    ];

    String displayEvent = eventTypeOrDescription;
    String displayStatus = statusOrInfo;

    if (allowedEventTypes.contains(eventTypeOrDescription)) {
      displayEvent = formatEventDescription(
        eventTypeOrDescription,
        metadata ?? {},
      );
      displayStatus = getEventStatus(eventTypeOrDescription, metadata ?? {});
    }

    _auditLogs.insert(0, {
      'time': timeStr,
      'event': displayEvent,
      'status': displayStatus,
    });
    _auditLogsStream.add(_auditLogs);
  }

  static String formatEventDescription(
    String eventType,
    Map<String, dynamic> metadata,
  ) {
    switch (eventType) {
      case 'file_uploaded':
        final name = metadata['file_name'] ?? 'document';
        final size = metadata['size_bytes'];
        final sizeStr = size != null ? ' ($size bytes)' : '';
        return 'Uploaded "$name"$sizeStr';
      case 'file_downloaded':
        final name = metadata['file_name'] ?? 'document';
        return 'Downloaded secure file "$name"';
      case 'file_viewed':
        final name = metadata['file_name'] ?? 'document';
        return 'Opened secure file "$name" in Spyglass Viewer';
      case 'file_deleted':
        final fileId = metadata['file_id'] ?? 'unknown';
        return 'Deleted secure file with ID "$fileId"';
      case 'file_renamed':
        final oldName = metadata['old_name'] ?? 'old';
        final newName = metadata['new_name'] ?? 'new';
        return 'Renamed secure file "$oldName" to "$newName"';
      case 'file_pinned':
        final name = metadata['file_name'] ?? 'document';
        final isPinned = metadata['is_pinned'] as bool? ?? true;
        return '${isPinned ? "Pinned" : "Unpinned"} secure file "$name"';
      case 'member_joined':
        final name = metadata['member_name'] ?? 'New user';
        return '$name joined the study group';
      case 'member_left':
        final name = metadata['member_name'] ?? 'User';
        return '$name left the study group';
      case 'member_promoted':
        final name = metadata['member_name'] ?? 'User';
        return '$name was promoted to admin';
      case 'member_demoted':
        final name = metadata['member_name'] ?? 'User';
        return '$name was demoted';
      case 'group_created':
        final name = metadata['group_name'] ?? 'group';
        return 'Created study group "$name"';
      case 'group_updated':
        final description = metadata['description'];
        if (description is String && description.isNotEmpty) {
          return description;
        }
        return 'Updated study group settings';
      case 'invite_generated':
        return 'Generated invite code for group';
      case 'invite_used':
        final name = metadata['member_name'] ?? 'User';
        return '$name joined group using invite code';
      case 'screenshot_attempt':
        final name = metadata['file_name'] ?? 'document';
        return 'Blocked screenshot attempt of "$name"';
      case 'recording_attempt':
        final name = metadata['file_name'] ?? 'document';
        return 'Blocked screen recording attempt of "$name"';
      case 'unauthorized_access':
        return 'Unauthorized access attempt blocked';
      default:
        return 'Security audit event triggered: $eventType';
    }
  }

  static String getEventStatus(
    String eventType,
    Map<String, dynamic> metadata,
  ) {
    if (eventType == 'screenshot_attempt' ||
        eventType == 'recording_attempt' ||
        eventType == 'unauthorized_access') {
      return 'SECURITY';
    }
    if (eventType.contains('viewed') ||
        eventType.contains('downloaded') ||
        eventType.contains('joined')) {
      return 'INFO';
    }
    return 'SUCCESS';
  }

  static String _extractFileName(String desc) {
    final match = RegExp(r'"([^"]+)"').firstMatch(desc);
    return match?.group(1) ?? 'document';
  }

  static String _extractFileId(String desc) {
    final match = RegExp(r'ID "([^"]+)"').firstMatch(desc);
    return match?.group(1) ?? 'unknown';
  }

  static String _extractGroupName(String desc) {
    final match = RegExp(r'"([^"]+)"').firstMatch(desc);
    return match?.group(1) ?? 'group';
  }

  Stream<List<Map<String, String>>> watchAuditLogs() {
    return Stream.multi((controller) {
      controller.add(List<Map<String, String>>.unmodifiable(_auditLogs));
      final sub = _auditLogsStream.stream.listen(
        (data) => controller.add(List<Map<String, String>>.unmodifiable(data)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  List<Map<String, String>> get auditLogs => _auditLogs;

  Future<Map<DateTime, int>> fetchAuditLogCounts() async {
    if (SupabaseService.instance.isReachable) {
      return await SupabaseService.instance.fetchAuditLogCounts();
    }
    return {};
  }

  void handleRestPollLogs(List<Map<String, String>> logsParsed) {
    _auditLogs.clear();
    _auditLogs.addAll(logsParsed);
    _auditLogsStream.add(_auditLogs);
  }

  void cancelStreams() {
    _auditLogsSub?.cancel();
    _auditLogsSub = null;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
