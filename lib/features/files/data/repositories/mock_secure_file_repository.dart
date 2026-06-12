import 'dart:async';
import 'dart:typed_data';
import '../../../../services/secure_db_service.dart';
import '../../../../features/groups/models/group_file.dart';
import '../../domain/models/secure_file_metadata.dart';
import '../../domain/repositories/secure_file_repository.dart';

class MockSecureFileRepository implements SecureFileRepository {
  const MockSecureFileRepository();

  @override
  Stream<List<SecureFileMetadata>> watchGroupFiles(String groupId) {
    return SecureDbService.instance.watchFiles().map((filesMap) {
      final list = filesMap[groupId] ?? [];
      return list.map(_mapGroupFile).toList();
    });
  }

  @override
  Stream<List<SecureFileMetadata>> watchAllFiles() {
    return SecureDbService.instance.watchFiles().map((filesMap) {
      return filesMap.values.expand((list) => list).map(_mapGroupFile).toList();
    });
  }

  @override
  Future<void> uploadFile({
    required String groupId,
    required String name,
    required SecureFileType type,
    required Uint8List rawBytes,
    required String uploaderName,
    required String uploaderInitials,
    required Function(double) onProgress,
  }) async {
    final legacyType = FileType.values.firstWhere(
      (e) => e.name == type.name,
      orElse: () => FileType.pdf,
    );
    await SecureDbService.instance.uploadFile(
      groupId: groupId,
      name: name,
      type: legacyType,
      rawBytes: rawBytes,
      uploaderName: uploaderName,
      uploaderInitials: uploaderInitials,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> deleteFile(String groupId, String fileId) {
    return SecureDbService.instance.deleteFile(groupId, fileId);
  }

  @override
  Future<void> togglePin(String groupId, String fileId) {
    return SecureDbService.instance.togglePin(groupId, fileId);
  }

  @override
  Future<void> addGoogleDriveLink({
    required String groupId,
    required String name,
    required SecureFileType type,
    required String driveUrl,
    required String uploaderName,
    required String uploaderInitials,
  }) async {
    final legacyType = FileType.values.firstWhere(
      (e) => e.name == type.name,
      orElse: () => FileType.pdf,
    );
    await SecureDbService.instance.addGoogleDriveLink(
      groupId: groupId,
      name: name,
      type: legacyType,
      driveUrl: driveUrl,
      uploaderName: uploaderName,
      uploaderInitials: uploaderInitials,
    );
  }

  @override
  Future<String?> getServiceAccountEmail() async {
    return "mock-drive-service-account@nosus.app";
  }

  @override
  Future<Uint8List?> downloadAndDecryptFile({
    required String fileId,
    required Function(double) onProgress,
  }) async {
    final decryptedBytes = SecureDbService.instance.downloadAndDecryptFile(fileId);
    if (decryptedBytes == null) return null;

    // Simulate progress updates
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(i / 5.0);
    }
    return decryptedBytes;
  }

  SecureFileMetadata _mapGroupFile(GroupFile f) {
    final domainType = SecureFileType.values.firstWhere(
      (e) => e.name == f.type.name,
      orElse: () => SecureFileType.pdf,
    );
    final status = SecureFileStatus.values.firstWhere(
      (e) => e.name == f.securityStatus.name,
      orElse: () => SecureFileStatus.secured,
    );
    return SecureFileMetadata(
      id: f.id,
      groupId: f.groupId,
      name: f.name,
      type: domainType,
      sizeBytes: f.sizeBytes,
      uploaderName: f.uploadedByName,
      uploadedAt: f.uploadedAt,
      isWatermarked: f.isWatermarked,
      isPinned: f.isPinned,
      status: status,
    );
  }
}
