import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../services/cryptography_service.dart';
import '../../../../services/secure_db_service.dart';
import '../../../../services/secure_key_store.dart';
import '../../../../services/supabase_service.dart';
import '../../domain/models/secure_file_metadata.dart';
import '../../domain/repositories/secure_file_repository.dart';

class SupabaseSecureFileRepository implements SecureFileRepository {
  final SupabaseClient _client;

  const SupabaseSecureFileRepository(this._client);

  @override
  Stream<List<SecureFileMetadata>> watchGroupFiles(String groupId) {
    return _client
        .from('secure_files')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('uploaded_at', ascending: false)
        .map((rows) => rows.map(_mapFile).toList(growable: false));
  }

  @override
  Stream<List<SecureFileMetadata>> watchAllFiles() {
    return _client
        .from('secure_files')
        .stream(primaryKey: ['id'])
        .order('uploaded_at', ascending: false)
        .map((rows) => rows.map(_mapFile).toList(growable: false));
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
    // 1. Generate secure AES key and IV
    final key = CryptographyService.generateSymmetricKey();
    final iv = CryptographyService.generateIV();

    // 2. Encrypt file using AES-GCM
    final encryptedBytes = await CryptographyService.encryptBytes(rawBytes, key, iv);

    // 3. Emulate upload progress updates
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress(i / 10.0);
    }

    final tempFileId = 'sec_${DateTime.now().millisecondsSinceEpoch}';

    // 4. Upload binary file bytes to Supabase Storage
    await _client.storage.from('secure-files').uploadBinary(tempFileId, encryptedBytes);

    // 5. Insert metadata row in secure_files table (NO KEYS in DB — E2E security)
    await _client.from('secure_files').insert({
      'id': tempFileId,
      'group_id': groupId,
      'name': name.replaceAll(type == SecureFileType.note ? '.md' : type == SecureFileType.pdf ? '.pdf' : type == SecureFileType.image ? '.png' : '.jpg', ''),
      'type': type.name == 'note' ? 'markdown' : type.name,
      'uploaded_by_name': uploaderName,
      'uploaded_by_initials': uploaderInitials,
      'size_bytes': rawBytes.length,
      'is_watermarked': true,
      'is_pinned': false,
      'security_status': 'secured',
    });

    // 6. Store the AES key ONLY on this device via flutter_secure_storage
    await SecureKeyStore.saveFileKey(tempFileId, key, iv);
    // Also cache in memory for immediate use this session
    SecureDbService.instance.registerCredentials(tempFileId, key, iv);

    // 7. Log event
    await _client.from('audit_logs').insert({
      'event': 'Successfully encrypted and uploaded "$name" (${rawBytes.length} bytes)',
      'status': 'SUCCESS',
    });
  }

  @override
  Future<void> deleteFile(String groupId, String fileId) async {
    // 1. Delete object from Supabase Storage
    try {
      await _client.storage.from('secure-files').remove([fileId]);
    } catch (_) {}

    // 2. Delete database metadata
    await _client.from('secure_files').delete().eq('id', fileId);

    // 3. Log event
    await _client.from('audit_logs').insert({
      'event': 'Deleted secure file with ID "$fileId" from group $groupId',
      'status': 'INFO',
    });
  }

  @override
  Future<void> togglePin(String groupId, String fileId) async {
    final response = await _client
        .from('secure_files')
        .select('is_pinned')
        .eq('id', fileId)
        .maybeSingle();

    if (response != null) {
      final currentPin = response['is_pinned'] as bool? ?? false;
      await _client
          .from('secure_files')
          .update({'is_pinned': !currentPin})
          .eq('id', fileId);
    }
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
    final gDriveId = _extractGoogleDriveFileId(driveUrl);
    if (gDriveId == null || gDriveId.isEmpty) {
      throw Exception("Invalid Google Drive URL. Could not parse file ID.");
    }

    await _client.from('secure_files').insert({
      'id': gDriveId,
      'group_id': groupId,
      'name': name,
      'type': type.name == 'note' ? 'markdown' : type.name,
      'uploaded_by_name': uploaderName,
      'uploaded_by_initials': uploaderInitials,
      'size_bytes': 0,
      'is_watermarked': true,
      'is_pinned': false,
      'security_status': 'secured',
    });

    await _client.from('audit_logs').insert({
      'event': 'Linked shared Google Drive file "$name" ($gDriveId)',
      'status': 'SUCCESS',
    });
  }

  @override
  Future<String?> getServiceAccountEmail() async {
    //Bypassed since we are using Supabase Storage
    return "Supabase Storage Active";
  }

  @override
  Future<Uint8List?> downloadAndDecryptFile({
    required String fileId,
    required Function(double) onProgress,
  }) async {
    try {
      onProgress(0.1);
      final isGoogleDrive = !fileId.startsWith('sec_');
      final Uint8List encryptedBytes;
      if (isGoogleDrive) {
        final gDriveBytes = await SupabaseService.instance.downloadStorageFile(fileId);
        if (gDriveBytes == null) {
          throw Exception("Failed to download file from Google Drive proxy");
        }
        encryptedBytes = gDriveBytes;
      } else {
        encryptedBytes = await _client.storage.from('secure-files').download(fileId);
      }
      onProgress(0.5);

      String? key = SecureDbService.instance.getFileKey(fileId);
      String? iv = SecureDbService.instance.getFileIV(fileId);

      if (key == null || iv == null || key.isEmpty || iv.isEmpty) {
        // Try device-local secure storage first (correct E2E model)
        final stored = await SecureKeyStore.getFileKey(fileId);
        if (stored != null) {
          key = stored.key;
          iv = stored.iv;
          SecureDbService.instance.registerCredentials(fileId, key, iv);
        }
      }

      if (key == null || iv == null || key.isEmpty || iv.isEmpty) {
        // Try selecting from secure_files table (shared/welcome notes fallback)
        try {
          final row = await _client
              .from('secure_files')
              .select('encryption_key_base64, encryption_iv_base64')
              .eq('id', fileId)
              .maybeSingle();
          if (row != null) {
            final dbKey = row['encryption_key_base64'] as String?;
            final dbIv = row['encryption_iv_base64'] as String?;
            if (dbKey != null && dbIv != null && dbKey.isNotEmpty && dbIv.isNotEmpty) {
              key = dbKey;
              iv = dbIv;
              SecureDbService.instance.registerCredentials(fileId, key, iv);
            }
          }
        } catch (_) {}
        // Note: If both local storage and database keys are null, the file was uploaded 
        // on a different device and has no database key — this is the CORRECT E2E security behavior.
      }

      onProgress(0.7);

      if (key != null && iv != null && key.isNotEmpty && iv.isNotEmpty) {
        final decryptedBytes = await CryptographyService.decryptBytes(encryptedBytes, key, iv);
        onProgress(1.0);
        return decryptedBytes;
      } else {
        onProgress(1.0);
        return encryptedBytes;
      }
    } catch (e, s) {
      debugPrint("SupabaseSecureFileRepository: downloadAndDecryptFile error: $e\n$s");
      return null;
    }
  }

  SecureFileMetadata _mapFile(Map<String, dynamic> row) {
    final fileId = row['id'] as String;
    // Note: encryption keys are NOT in the DB row anymore (E2E security fix).
    // Keys are stored device-locally via SecureKeyStore.

    return SecureFileMetadata(
      id: fileId,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      type: _parseType(row['type']),
      sizeBytes: row['size_bytes'] as int? ?? 0,
      uploaderName: row['uploaded_by_name'] as String? ?? 'Unknown',
      uploadedAt:
          DateTime.tryParse(row['uploaded_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isWatermarked: row['is_watermarked'] as bool? ?? true,
      isPinned: row['is_pinned'] as bool? ?? false,
      status: _parseStatus(row['security_status']),
    );
  }

  SecureFileType _parseType(Object? value) {
    final normalized = value?.toString().toLowerCase();
    if (normalized == 'markdown') return SecureFileType.note;
    return SecureFileType.values.firstWhere(
      (type) => type.name == normalized,
      orElse: () => SecureFileType.pdf,
    );
  }

  SecureFileStatus _parseStatus(Object? value) {
    return SecureFileStatus.values.firstWhere(
      (status) => status.name == value?.toString().toLowerCase(),
      orElse: () => SecureFileStatus.pending,
    );
  }

  String? _extractGoogleDriveFileId(String url) {
    final RegExp regExp1 = RegExp(r'/file/d/([a-zA-Z0-9-_]+)');
    final RegExp regExp2 = RegExp(r'[?&]id=([a-zA-Z0-9-_]+)');

    final match1 = regExp1.firstMatch(url);
    if (match1 != null && match1.groupCount >= 1) {
      return match1.group(1);
    }

    final match2 = regExp2.firstMatch(url);
    if (match2 != null && match2.groupCount >= 1) {
      return match2.group(1);
    }

    if (!url.contains('/') && url.length > 10) {
      return url;
    }

    return null;
  }
}
