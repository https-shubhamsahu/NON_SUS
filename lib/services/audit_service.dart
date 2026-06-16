import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

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
    if (SupabaseService.instance.isReachable) {
      _auditLogsSub = SupabaseService.instance.watchAuditLogs().listen(
        (data) {
          _auditLogs.clear();
          _auditLogs.addAll(data);
          _auditLogsStream.add(_auditLogs);
        },
        onError: (e) {
          debugPrint("AuditService: watchAuditLogs stream error, offline fallback active. $e");
        },
        cancelOnError: true,
      );
    }
  }

  void logEvent(String event, String status) {
    if (SupabaseService.instance.isReachable) {
      SupabaseService.instance.logEvent(event, status);
      return;
    }

    final now = DateTime.now();
    final timeStr = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
    _auditLogs.insert(0, {'time': timeStr, 'event': event, 'status': status});
    _auditLogsStream.add(_auditLogs);
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
