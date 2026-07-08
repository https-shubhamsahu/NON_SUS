import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/audit_service.dart';
import '../../auth/presentation/providers/auth_providers.dart';

class AuditLogsNotifier extends Notifier<List<Map<String, String>>> {
  StreamSubscription? _sub;

  @override
  List<Map<String, String>> build() {
    final user = ref.watch(authStateProvider).value;
    
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());

    if (user == null) {
      AuditService.instance.reset();
      return const [];
    }

    // Re-initialize AuditService with the new user session
    AuditService.instance.init();

    _sub = AuditService.instance.watchAuditLogs().listen((data) {
      state = data;
    });

    return AuditService.instance.auditLogs;
  }

  void addLog(String event, String status) {
    AuditService.instance.logEvent(event, status);
  }
}

final auditLogsProvider =
    NotifierProvider<AuditLogsNotifier, List<Map<String, String>>>(
      AuditLogsNotifier.new,
    );
