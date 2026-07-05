/// Repository interface for interacting with the FHE microservice.
abstract class FheRepository {
  /// Submits an asynchronous homomorphic computation job
  Future<String> submitComputeJob({
    required String keyId,
    required String operation,
    required List<String> ciphertexts,
    int? priority,
    int? timeoutSeconds,
  });

  /// Retrieves the current status, progress, and result of a job
  Future<Map<String, dynamic>> getJobStatus(String jobId);

  /// Aborts a pending or running job
  Future<bool> cancelJob(String jobId);
}
