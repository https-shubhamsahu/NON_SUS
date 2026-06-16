import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/secure_db_service.dart';

class AuditLogsNotifier extends Notifier<List<Map<String, String>>> {
  StreamSubscription? _sub;

  @override
  List<Map<String, String>> build() {
    _sub?.cancel();
    _sub = SecureDbService.instance.watchAuditLogs().listen((data) {
      state = data;
    });
    ref.onDispose(() => _sub?.cancel());

    return SecureDbService.instance.auditLogs;
  }

  void addLog(String event, String status) {
    SecureDbService.instance.logEvent(event, status);
  }
}

final auditLogsProvider =
    NotifierProvider<AuditLogsNotifier, List<Map<String, String>>>(
      AuditLogsNotifier.new,
    );
