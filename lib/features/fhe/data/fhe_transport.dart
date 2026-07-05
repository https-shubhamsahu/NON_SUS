import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../config/fhe_config.dart';
import '../../../core/utils/debug_logger.dart';

/// Single transport for ALL FHE traffic leaving the app.
///
/// Production path: `Supabase.functions.invoke('fhe-proxy', ...)`, which
/// automatically attaches the authenticated user's JWT. The Edge Function then
/// authenticates the tenant, enforces replay protection, and forwards to the
/// Rust microservice. The app never sees the service URL or token.
///
/// Local-dev path (FHE_USE_LOCAL_COMPUTE=true): talks directly to a Rust
/// service on the host for on-device debugging. Never use in release builds.
class FheTransport {
  FheTransport._();
  static final FheTransport instance = FheTransport._();

  static const _uuid = Uuid();

  /// Maps a logical action to the Rust service's local path (dev mode only).
  static const Map<String, String> _localPaths = {
    'generate_keys': '/keys/generate',
    'rotate_keys': '/keys/rotate',
    'revoke_keys': '/keys/revoke',
    'encrypt': '/encrypt',
    'decrypt': '/decrypt',
    'compute': '/compute',
    'submit_job': '/jobs',
    'compare': '/compare',
    'mux': '/mux',
    'memory_search': '/memory/search',
    'policy_evaluate': '/policy/evaluate',
    'similarity': '/similarity',
    'pact_evaluate': '/pact/evaluate',
    'pact_seal': '/pact/seal',
    'pact_decrypt': '/pact/decrypt',
  };

  /// Sends an FHE request and returns the decoded `result` object.
  ///
  /// Every call carries a nonce, request id and timestamp so the server can
  /// reject replays. Throws [StateError] if no capability flag is enabled.
  Future<Map<String, dynamic>> send(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE is disabled: no capability flag is enabled.');
    }

    final envelope = {
      'action': action,
      'nonce': _uuid.v4(),
      'request_id': _uuid.v4(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
    };

    if (FheConfig.useLocalCompute) {
      return _sendLocal(action, payload);
    }
    return _sendViaEdge(envelope);
  }

  Future<Map<String, dynamic>> _sendViaEdge(
    Map<String, dynamic> envelope,
  ) async {
    final res = await Supabase.instance.client.functions.invoke(
      FheConfig.edgeFunctionName,
      body: envelope,
    );

    if (res.status != 200) {
      throw Exception('FHE proxy error (${res.status}): ${res.data}');
    }
    final data = res.data;
    if (data is Map && data['result'] is Map) {
      final result = Map<String, dynamic>.from(data['result'] as Map);
      final mirroredJobId = data['job_id'];
      if (mirroredJobId != null) {
        result['edge_job_id'] = mirroredJobId;
        result.putIfAbsent('job_id', () => mirroredJobId);
      }
      result['request_id'] = data['request_id'];
      return result;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected FHE proxy response shape');
  }

  Future<Map<String, dynamic>> _sendLocal(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final path = _localPaths[action];
    if (path == null) throw Exception('Unknown local FHE action: $action');

    final res = await http.post(
      Uri.parse('${FheConfig.localComputeUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${FheConfig.localServiceToken}',
      },
      body: jsonEncode(payload),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Local FHE error (${res.statusCode}): ${res.body}');
    }
    debugLog('FHE local call $action -> ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
