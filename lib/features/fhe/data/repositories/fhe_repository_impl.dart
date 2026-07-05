import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/fhe_config.dart';
import '../../domain/repositories/fhe_repository.dart';
import '../fhe_transport.dart';

/// Async compute-job repository. Submits jobs through the Edge Function and
/// reads status from the `fhe_compute_jobs` table (RLS-scoped to the caller),
/// which is also the realtime channel for push updates.
class FheRepositoryImpl implements FheRepository {
  @override
  Future<String> submitComputeJob({
    required String keyId,
    required String operation,
    required List<String> ciphertexts,
    int? priority,
    int? timeoutSeconds,
  }) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE feature flags are disabled.');
    }

    final res = await FheTransport.instance.send('submit_job', {
      'key_id': keyId,
      'operation': operation,
      'ciphertexts': ciphertexts,
      'priority': priority ?? 1,
      'timeout_seconds': timeoutSeconds ?? 30,
    });

    final jobId = res['edge_job_id'] ?? res['job_id'] ?? res['id'];
    if (jobId == null) {
      throw Exception('FHE proxy did not return a job id');
    }
    return jobId.toString();
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE feature flags are disabled.');
    }

    // Read from the RLS-protected mirror table (single source of truth for the
    // client). The worker updates it; realtime pushes changes.
    final row = await Supabase.instance.client
        .from('fhe_compute_jobs')
        .select()
        .eq('id', jobId)
        .maybeSingle();

    if (row == null) {
      return {'status': 'not_found', 'progress': 0.0};
    }
    return {
      'status': row['status'],
      'progress': (row['progress'] as num?)?.toDouble() ?? 0.0,
      'result': row['result_ciphertext'],
      'error': row['error'],
    };
  }

  @override
  Future<bool> cancelJob(String jobId) async {
    if (!FheConfig.anyEnabled) {
      throw StateError('FHE feature flags are disabled.');
    }
    // RLS policy fhe_jobs_cancel_own permits the owner to set cancelled.
    await Supabase.instance.client
        .from('fhe_compute_jobs')
        .update({'status': 'cancelled'})
        .eq('id', jobId);
    return true;
  }
}
