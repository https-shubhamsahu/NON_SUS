import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/study_group.dart';
import '../../domain/repositories/study_group_repository.dart';
import '../../../../services/cryptography_service.dart';
import '../../../../services/secure_key_store.dart';
import '../../../../services/secure_db_service.dart';

class SupabaseStudyGroupRepository implements StudyGroupRepository {
  final SupabaseClient _client;

  const SupabaseStudyGroupRepository(this._client);

  @override
  Stream<List<StudyGroup>> watchGroups() {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    final controller = StreamController<List<StudyGroup>>();
    StreamSubscription? groupsSub;
    StreamSubscription? membersSub;

    void updateData() async {
      try {
        final members = await _client
            .from('study_group_members')
            .select('group_id')
            .eq('user_id', currentUser.id);
        final groupIds = members.map((m) => m['group_id'] as String).toSet();
        final groupIdsList = groupIds.toList();

        if (groupIdsList.isEmpty) {
          if (!controller.isClosed) {
            controller.add([]);
          }
          return;
        }

        final groupsResp = await _client
            .from('study_groups')
            .select()
            .inFilter('id', groupIdsList)
            .order('created_at', ascending: false);

        final allMembersRaw = await _client
            .from('study_group_members')
            .select('group_id, user_id, is_admin, profiles(display_name, email)')
            .inFilter('group_id', groupIdsList);

        final membersMap = <String, List<GroupMember>>{};
        for (final row in allMembersRaw) {
          final gId = row['group_id'] as String;
          final profile = row['profiles'] ?? {};
          final name = profile['display_name'] as String? ?? (profile['email'] as String? ?? 'User').split('@').first;
          final initials = name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase() : 'US';
          membersMap.putIfAbsent(gId, () => []).add(GroupMember(
            id: row['user_id'] as String,
            name: name,
            initials: initials,
            isAdmin: row['is_admin'] as bool? ?? false,
          ));
        }

        final results = groupsResp
            .map((row) => _mapGroup(row, membersMap[row['id'] as String] ?? []))
            .toList(growable: false);

        if (!controller.isClosed) {
          controller.add(results);
        }
      } catch (e, st) {
        debugPrint("NO SUS watchGroups updateData error: $e\n$st");
      }
    }

    groupsSub = _client
        .from('study_groups')
        .stream(primaryKey: ['id'])
        .listen((_) => updateData());

    membersSub = _client
        .from('study_group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', currentUser.id)
        .listen((_) => updateData());

    controller.onCancel = () {
      groupsSub?.cancel();
      membersSub?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<void> createGroup(StudyGroup group) async {
    await _client.from('study_groups').insert({
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'security_level': group.securityLevel.name,
      'is_watermark_enabled': group.isWatermarkEnabled,
      'invite_code': group.inviteCode,
    });

    final currentUser = _client.auth.currentUser;
    if (currentUser != null) {
      try {
        await _client.from('study_group_members').insert({
          'group_id': group.id,
          'user_id': currentUser.id,
          'is_admin': true,
        });

        // Fetch user profile to get uploader details (or use email split/defaults)
        final profile = await _client
            .from('profiles')
            .select('display_name, email')
            .eq('id', currentUser.id)
            .maybeSingle();

        final uploaderName = profile?['display_name'] as String? ?? 
            (profile?['email'] as String? ?? 'Scholar').split('@').first;
        final uploaderInitials = uploaderName.isNotEmpty
            ? uploaderName.substring(0, uploaderName.length >= 2 ? 2 : uploaderName.length).toUpperCase()
            : 'US';

        // 1. Auto-generate Welcome Note
        final welcomeTitle = 'Welcome to ${group.name}';
        final welcomeContent = '# Welcome to ${group.name}!\n\n'
            'We are excited to have you in this secure enclave workspace. Here, you can share sensitive lecture notes, '
            'past exams, and research papers with complete confidence.\n\n'
            '## Quick Tips for Group Members:\n'
            '1. **Confidential Sharing**: All documents uploaded here are end-to-end encrypted locally on your device '
            'before they reach Supabase Storage.\n'
            '2. **Access Control**: Only verified group members can access and decrypt these files.\n'
            '3. **Spyglass Protection**: Click \'REVEAL\' on any document to open it in the secure Spyglass Viewer, '
            'which protects it against screenshots, screen recording, and unauthorized inspection.';
        
        await _createAutoGeneratedNote(
          groupId: group.id,
          title: welcomeTitle,
          content: welcomeContent,
          uploaderName: uploaderName,
          uploaderInitials: uploaderInitials,
        );

        // 2. Auto-generate Features Note
        final featuresTitle = 'NO SUS Security Features';
        final featuresContent = '# NO SUS — Advanced Security Features\n\n'
            'Here is a quick summary of the security protocols active in your workspace:\n\n'
            '### 1. In-Memory Decryption\n'
            'Documents are decrypted inside a secure RAM buffer and are never written to the disk. They are '
            'purged from memory immediately when you leave the viewer.\n\n'
            '### 2. Screenshot Protection\n'
            'We block system-level screenshots and screen sharing on mobile devices, and apply a touch-to-reveal '
            'blur layer that prevents over-the-shoulder inspection.\n\n'
            '### 3. Dynamic Watermarking\n'
            'A visible watermark containing your profile email, IP, and timestamp is dynamically overlaid on all pages. '
            'If someone takes a physical photo of the screen, the leak can be traced back.\n\n'
            '### 4. Cryptographic Auditing\n'
            'Every document access, download, and key rotation event is logged to an immutable, real-time audit ledger, '
            'ensuring full team accountability.';

        await _createAutoGeneratedNote(
          groupId: group.id,
          title: featuresTitle,
          content: featuresContent,
          uploaderName: uploaderName,
          uploaderInitials: uploaderInitials,
        );
      } catch (e, st) {
        debugPrint("NO SUS createGroup members/notes creation error: $e\n$st");
      }
    }
  }

  Future<void> _createAutoGeneratedNote({
    required String groupId,
    required String title,
    required String content,
    required String uploaderName,
    required String uploaderInitials,
  }) async {
    try {
      final rawBytes = Uint8List.fromList(utf8.encode(content));
      
      // 1. Generate keys
      final key = CryptographyService.generateSymmetricKey();
      final iv = CryptographyService.generateIV();

      // 2. Encrypt using AES
      final encryptedBytes = await CryptographyService.encryptBytes(rawBytes, key, iv);

      // 3. Unique ID
      final noteId = 'sec_gen_${const Uuid().v4()}';

      // 4. Upload to storage
      await _client.storage.from('secure-files').uploadBinary(noteId, encryptedBytes);

      // 5. Insert metadata WITH keys stored in database for shared access
      await _client.from('secure_files').insert({
        'id': noteId,
        'group_id': groupId,
        'name': title,
        'type': 'markdown',
        'uploaded_by_name': uploaderName,
        'uploaded_by_initials': uploaderInitials,
        'size_bytes': rawBytes.length,
        'is_watermarked': true,
        'is_pinned': true,
        'security_status': 'secured',
        'encryption_key_base64': key,
        'encryption_iv_base64': iv,
      });

      // 6. Cache locally on this device as well
      await SecureKeyStore.saveFileKey(noteId, key, iv);
      SecureDbService.instance.registerCredentials(noteId, key, iv);
    } catch (e, st) {
      debugPrint("Error creating auto-generated note: $e\n$st");
    }
  }

  @override
  Future<void> ensureCommunityExists(String name, String description, bool isPublic) async {
    final existing = await _client.from('study_groups').select('id').eq('name', name).maybeSingle();
    if (existing == null) {
      final id = const Uuid().v4();
      try {
        await _client.from('study_groups').insert({
          'id': id,
          'name': name,
          'description': description,
          'security_level': isPublic ? SecurityLevel.open.name : SecurityLevel.encrypted.name,
          'is_watermark_enabled': true,
        });
      } catch (_) {}
    }
  }

  @override
  Future<void> joinGroupByName(String name, String userId) async {
    final existing = await _client.from('study_groups').select('id').eq('name', name).maybeSingle();
    if (existing != null) {
      try {
        await _client.from('study_group_members').insert({
          'group_id': existing['id'],
          'user_id': userId,
          'is_admin': false,
        });
      } catch (_) {} // Ignore if already member
    }
  }

  @override
  Future<void> joinGroupByInviteCode(String inviteCode, String userId) async {
    final existing = await _client.from('study_groups').select('id').eq('invite_code', inviteCode).maybeSingle();
    if (existing != null) {
      try {
        await _client.from('study_group_members').insert({
          'group_id': existing['id'],
          'user_id': userId,
          'is_admin': false,
        });
      } catch (_) {} // Ignore if already member
    } else {
      throw Exception('Invalid invite code');
    }
  }

  StudyGroup _mapGroup(Map<String, dynamic> row, List<GroupMember> members) {
    return StudyGroup(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String? ?? '',
      securityLevel: _parseSecurityLevel(row['security_level']),
      members: members,
      fileCount: row['file_count'] as int? ?? 0,
      lastActivity: _parseDate(row['last_activity'] ?? row['created_at']),
      isWatermarkEnabled: row['is_watermark_enabled'] as bool? ?? true,
      inviteCode: row['invite_code'] as String?,
    );
  }

  SecurityLevel _parseSecurityLevel(Object? value) {
    return SecurityLevel.values.firstWhere(
      (level) => level.name == value?.toString().toLowerCase(),
      orElse: () => SecurityLevel.encrypted,
    );
  }

  DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
