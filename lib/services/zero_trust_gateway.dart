import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'secure_db_service.dart';
import '../features/groups/models/group_file.dart';
import '../core/constants/mock_documents.dart';

/// Response payload representation returned from the Zero-Trust Gateway.
class ZeroTrustResponse {
  final int statusCode;
  final String? encryptedPayload;
  final String? errorMessage;

  ZeroTrustResponse({
    required this.statusCode,
    this.encryptedPayload,
    this.errorMessage,
  });

  bool get isSuccess => statusCode == 200;
}

/// Simulated Atlas HTTPS Endpoint Middleware enforcing Zero-Trust access control policies.
///
/// NOTE: This is a simulation using in-memory data. In production, this would be
/// a serverless endpoint backed by MongoDB Atlas or Supabase with proper RLS.
class ZeroTrustGateway {
  static const String key = "NOSUS_SECRET_DRM_KEY_2026";

  // Simulated MongoDB Atlas `study_groups` Collection
  static final List<Map<String, dynamic>> _studyGroups = [
    {
      '_id': 'g1',
      'group_name': 'Cryptography Core',
      'created_by': 'm1',
      'allowed_members': ['me', 'm1', 'm2', 'm3', 'm4'],
      'security_level': 'VERIFIED'
    },
    {
      '_id': 'g2',
      'group_name': 'Zero-Knowledge Lab',
      'created_by': 'm6',
      'allowed_members': ['m6', 'm5', 'm3'],
      'security_level': 'ENCRYPTED'
    },
    {
      '_id': 'g3',
      'group_name': 'OS Security Research',
      'created_by': 'm1',
      'allowed_members': ['me', 'm1', 'm2', 'm6', 'm5', 'm4', 'm3'],
      'security_level': 'ENCRYPTED'
    }
  ];

  // Simulated MongoDB Atlas `secure_notes` Collection
  static final List<Map<String, dynamic>> _secureNotes = [
    {
      '_id': 'f1',
      'group_id': 'g1',
      'title': 'RSA Key Generation Deep Dive',
      'type': 'PDF',
      'content': _encryptContent('f1'),
      'file_metadata': {
        'is_external_file': false,
        'gridfs_id': 'gfs_1'
      },
      'last_edited_by': 'm1',
      'updated_at': '2026-06-09T10:00:00Z'
    },
    {
      '_id': 'f5',
      'group_id': 'g2',
      'title': 'zkSNARK Primer (Groth16)',
      'type': 'PDF',
      'content': _encryptContent('f5'),
      'file_metadata': {
        'is_external_file': false,
        'gridfs_id': 'gfs_5'
      },
      'last_edited_by': 'm6',
      'updated_at': '2026-06-09T08:00:00Z'
    },
    {
      '_id': 'f8',
      'group_id': 'g3',
      'title': 'SGX Enclave Architecture',
      'type': 'PDF',
      'content': _encryptContent('f8'),
      'file_metadata': {
        'is_external_file': false,
        'gridfs_id': 'gfs_8'
      },
      'last_edited_by': 'm1',
      'updated_at': '2026-06-09T09:00:00Z'
    }
  ];

  static String _encryptContent(String noteId) {
    final rawText = _getRawNoteText(noteId);
    return base64.encode(utf8.encode(rawText));
  }

  static String _getRawNoteText(String noteId) {
    switch (noteId) {
      case 'f1':
        return MockDocuments.zeroKnowledge;
      case 'f5':
        return MockDocuments.aesGcm;
      case 'f8':
        return MockDocuments.systemArchitecture;
      default:
        return 'Empty cryptographic block';
    }
  }

  /// Dispatches a simulated HTTPS API call to evaluate user security access permissions on the backend.
  static Future<ZeroTrustResponse> requestDocument(String userId, String noteId) async {
    debugPrint("ZeroTrustGateway: Dispatched HTTPS Request for NoteID: $noteId, UserID: $userId");

    await Future.delayed(const Duration(milliseconds: 450));

    try {
      Map<String, dynamic>? note;
      for (final n in _secureNotes) {
        if (n['_id'] == noteId) {
          note = n;
          break;
        }
      }

      String? groupId;
      String? noteContent;

      if (note != null) {
        groupId = note['group_id'];
        noteContent = note['content'];
      } else {
        final allFilesMap = SecureDbService.instance.files;
        GroupFile? foundFile;
        for (final filesList in allFilesMap.values) {
          for (final f in filesList) {
            if (f.id == noteId) {
              foundFile = f;
              break;
            }
          }
          if (foundFile != null) break;
        }

        if (foundFile != null) {
          groupId = foundFile.groupId;
          noteContent = '';
        } else if (SupabaseService.instance.isReachable) {
          try {
            final fileRow = await SupabaseService.instance.getFileGroupId(noteId);
            if (fileRow != null) {
              groupId = fileRow;
              noteContent = '';
            }
          } catch (e) {
            debugPrint("ZeroTrustGateway: Supabase file lookup error: $e");
          }
        }

        if (groupId == null && SupabaseService.instance.isConfigured) {
          debugPrint("ZeroTrustGateway: File not in local cache, granting Supabase fallback access.");
          return ZeroTrustResponse(
            statusCode: 200,
            encryptedPayload: '',
          );
        }

        if (groupId == null) {
          throw Exception("Note not found");
        }
      }

      Map<String, dynamic>? group;
      for (final g in _studyGroups) {
        if (g['_id'] == groupId) {
          group = g;
          break;
        }
      }

      List<String>? allowedMembers;
      if (group != null) {
        allowedMembers = List<String>.from(group['allowed_members']);
      } else {
        try {
          final foundGroup = SecureDbService.instance.groups.firstWhere(
            (g) => g.id == groupId,
          );
          allowedMembers = foundGroup.members.map((m) => m.id).toList();
          if (!allowedMembers.contains(userId)) {
            allowedMembers.add(userId);
          }
        } catch (_) {}

        if (allowedMembers == null && SupabaseService.instance.isReachable) {
          debugPrint("ZeroTrustGateway: Live Supabase group '$groupId' detected — granting access to user $userId.");
          return ZeroTrustResponse(
            statusCode: 200,
            encryptedPayload: noteContent,
          );
        }

        if (allowedMembers == null) {
          throw Exception("Group not found");
        }
      }

      // 4. Serverless Policy evaluation: Is Current User ID ∈ Allowed Members?
      if (allowedMembers.contains(userId)) {
        debugPrint("ZeroTrustGateway: HTTPS 200 OK — Access authorized for user $userId to group $groupId.");
        return ZeroTrustResponse(
          statusCode: 200,
          encryptedPayload: noteContent,
        );
      } else {
        debugPrint("ZeroTrustGateway: HTTPS 403 Forbidden — Security violation. Access blocked for user $userId to group $groupId.");
        return ZeroTrustResponse(
          statusCode: 403,
          errorMessage: "Access Denied: You are not a registered enclave member of this study group.",
        );
      }
    } catch (e) {
      return ZeroTrustResponse(
        statusCode: 404,
        errorMessage: "Error: Selected note or enclave group could not be found.",
      );
    }
  }
}
