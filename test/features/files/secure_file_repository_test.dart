import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_sus/features/files/data/repositories/mock_secure_file_repository.dart';
import 'package:no_sus/features/files/domain/models/secure_file_metadata.dart';
import 'package:no_sus/features/groups/domain/models/study_group.dart';
import 'package:no_sus/services/secure_db_service.dart';

void main() {
  test('MockSecureFileRepository uploads, downloads, and decrypts file', () async {
    const repository = MockSecureFileRepository();
    
    // 1. Create a study group
    final group = StudyGroup(
      id: 'test-group-1',
      name: 'Test Group',
      description: 'Test Description',
      securityLevel: SecurityLevel.encrypted,
      members: const [],
      fileCount: 0,
      lastActivity: DateTime.now(),
    );
    await SecureDbService.instance.createGroup(group);

    // 2. Upload a secure file
    final rawBytes = Uint8List.fromList('Test file content bytes'.codeUnits);
    await repository.uploadFile(
      groupId: 'test-group-1',
      name: 'test_doc.txt',
      type: SecureFileType.pdf,
      rawBytes: rawBytes,
      uploaderName: 'Tester',
      uploaderInitials: 'TT',
      onProgress: (_) {},
    );

    // Find the uploaded file ID
    final filesMap = SecureDbService.instance.files;
    final uploadedFiles = filesMap['test-group-1'];
    expect(uploadedFiles, isNotNull);
    expect(uploadedFiles!.isNotEmpty, true);
    final fileId = uploadedFiles.first.id;

    // 3. Download and decrypt the file
    final progressLog = <double>[];
    final decryptedBytes = await repository.downloadAndDecryptFile(
      fileId: fileId,
      onProgress: (p) => progressLog.add(p),
    );

    // 4. Assert correctness
    expect(decryptedBytes, isNotNull);
    final decryptedString = String.fromCharCodes(decryptedBytes!);
    expect(decryptedString, 'Test file content bytes');
    expect(progressLog, containsAllInOrder([0.2, 0.4, 0.6, 0.8, 1.0]));
  });
}
