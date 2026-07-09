import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/debug_logger.dart';
import 'audit_service.dart';
import 'supabase_service.dart';

/// Aggregates device/session-level tamper signals from the native Android
/// scanner (root, Frida/Xposed/LSPosed instrumentation, display mirroring,
/// accessibility-service abuse).
///
/// Two different findings get logged to two different ledgers, deliberately:
///
/// - Root/instrumentation are properties of the *device*, not of any one
///   group action, so [runStartupChecks] writes them to the self-scoped
///   `device_integrity_events` hash chain (see [SupabaseService.logDeviceIntegrityEvent]).
/// - Display mirroring and accessibility abuse are checked per viewing
///   session in [runViewingChecks] and logged into the existing group-scoped
///   `audit_logs` chain via [AuditService], exactly like screenshot_attempt —
///   because "was someone mirroring my screen while I viewed this document"
///   is a fact about that document's audit trail, not about the device.
///
/// Policy for this app (see project decision): findings are logged, not used
/// to block access — a false positive (e.g. a legitimately rooted power-user
/// phone) should never lock a user out of their own notes.
class DeviceIntegrityService {
  DeviceIntegrityService._();
  static final DeviceIntegrityService instance = DeviceIntegrityService._();

  static const _channel = MethodChannel('co.nosus.app/device_integrity');
  static const _deviceIdPrefsKey = 'nosus_device_id_v1';

  String? _deviceId;
  bool _startupScanDone = false;
  bool _deviceRegistered = false;

  /// Stable per-install identifier, persisted locally. Deliberately *not*
  /// a hardware ID (IMEI/serial/etc.) — this app doesn't collect those, in
  /// keeping with the no-third-party-tracking privacy stance (see
  /// web/privacy.html). It only needs to be stable enough to notice
  /// "this same device flagged again" and "multiple devices for one user".
  Future<String> get deviceId async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPrefsKey);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdPrefsKey, id);
    }
    _deviceId = id;
    return id;
  }

  Future<Map<String, dynamic>?> _runNativeScan() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod('runChecks');
      if (raw is! Map) return null;
      return Map<String, dynamic>.from(raw);
    } catch (e) {
      debugLog('DeviceIntegrityService: native scan failed: $e');
      return null;
    }
  }

  /// Call once per app launch (see main.dart). Fire-and-forget — never
  /// awaited by startup code, since file/socket probing shouldn't delay
  /// first paint.
  Future<void> runStartupChecks() async {
    if (_startupScanDone) return;
    _startupScanDone = true;

    final result = await _runNativeScan();
    if (result == null) return;

    final id = await deviceId;

    final root = Map<String, dynamic>.from(result['root'] as Map? ?? {});
    if (root['rooted'] == true) {
      await SupabaseService.instance.logDeviceIntegrityEvent(
        eventType: 'root_detected',
        severity: 'warning',
        deviceId: id,
        metadata: {'reasons': root['reasons']},
      );
    }

    final instrumentation =
        Map<String, dynamic>.from(result['instrumentation'] as Map? ?? {});
    if (instrumentation['instrumented'] == true) {
      await SupabaseService.instance.logDeviceIntegrityEvent(
        eventType: 'tamper_detected',
        severity: 'critical',
        deviceId: id,
        metadata: {'reasons': instrumentation['reasons']},
      );
    }
  }

  /// Call once per app session, right after a user is confirmed signed in
  /// (see AuthGate) — needs auth.uid() server-side, so it can't run before
  /// that. Platform-agnostic (works on web too, unlike the native root/
  /// instrumentation scan): just a persisted device id + a Supabase RPC.
  Future<void> registerDeviceSeen() async {
    if (_deviceRegistered) return;
    _deviceRegistered = true;
    try {
      final id = await deviceId;
      await SupabaseService.instance.registerDeviceSeen(id);
    } catch (e) {
      debugLog('DeviceIntegrityService: registerDeviceSeen failed: $e');
    }
  }

  /// Call when a sensitive viewer (Spyglass, secure notes, etc.) opens.
  /// Checks display mirroring + accessibility abuse *for this viewing
  /// session* and logs into the group's tamper-evident audit trail.
  Future<void> runViewingChecks({
    required String? groupId,
    String? fileId,
  }) async {
    if (groupId == null) return;

    final result = await _runNativeScan();
    if (result == null) return;

    final mirroring =
        Map<String, dynamic>.from(result['displayMirroring'] as Map? ?? {});
    if (mirroring['mirroring'] == true) {
      AuditService.instance.logEvent(
        'display_mirroring_detected',
        'SECURITY',
        groupId: groupId,
        fileId: fileId,
        metadata: {'displays': mirroring['displays']},
      );
    }

    final accessibility =
        Map<String, dynamic>.from(result['accessibility'] as Map? ?? {});
    if (accessibility['suspiciousServicesFound'] == true) {
      AuditService.instance.logEvent(
        'accessibility_detected',
        'SECURITY',
        groupId: groupId,
        fileId: fileId,
        metadata: {'services': accessibility['services']},
      );
    }
  }
}
