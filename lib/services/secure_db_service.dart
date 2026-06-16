import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/groups/domain/models/study_group.dart';
import '../features/groups/models/group_file.dart';
import '../features/groups/data/mock_groups_data.dart';
import 'cryptography_service.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_preferences_service.dart';
import 'audit_service.dart';
import 'focus_service.dart';

/// Unified Repository Database Service.
///
/// Implements the Repository Pattern: if Supabase credentials are configured,
/// queries are routed dynamically to [SupabaseService] backend endpoints.
/// Otherwise, falls back gracefully to in-memory reactive mock data pools.
class SecureDbService {
  // Singleton instance
  static final SecureDbService instance = SecureDbService._internal();
  SecureDbService._internal() {
    _init();
  }

  // In-memory simulated cloud collections (mock fallback)
  final List<StudyGroup> _groups = List<StudyGroup>.from(MockGroupsData.groups);
  final Map<String, List<GroupFile>> _files = {};

  Future<void> loadPersistedState() async => await AppPreferencesService.instance.loadPersistedState();
  bool isOnboardingCompleted() => AppPreferencesService.instance.isOnboardingCompleted();
  Future<void> completeOnboarding() async => await AppPreferencesService.instance.completeOnboarding();
  bool isGuestMode() => AppPreferencesService.instance.isGuestMode();
  Future<void> setGuestMode(bool value) async => await AppPreferencesService.instance.setGuestMode(value);
  String get userType => AppPreferencesService.instance.userType;
  Future<void> setUserType(String value) async => await AppPreferencesService.instance.setUserType(value);
  Future<void> resetAppState() async => await AppPreferencesService.instance.resetAppState();

  // In-memory encrypted binary vaults mimicking AWS S3 or Google Cloud Storage buckets
  final Map<String, Uint8List> _encryptedStorageBucket = {};
  final Map<String, String> _fileKeys = {}; // fileId -> keyBase64
  final Map<String, String> _fileIVs = {}; // fileId -> ivBase64

  // StreamControllers to publish real-time database updates for local fallback
  final StreamController<List<StudyGroup>> _groupsStream =
      StreamController<List<StudyGroup>>.broadcast();
  final StreamController<Map<String, List<GroupFile>>> _filesStream =
      StreamController<Map<String, List<GroupFile>>>.broadcast();
  // Supabase stream subscription handles — stored so we can cancel them on failure
  StreamSubscription? _groupsSub;
  StreamSubscription? _filesSub;

  void _init() {
    if (SupabaseService.instance.isReachable) {
      _initSupabaseStreams();
      return;
    }
    _initMockFallback();
  }

  // Polling timer used when realtime is unavailable
  Timer? _pollTimer;

  void _initSupabaseStreams() {
    debugPrint(
      "SecureDbService: Supabase active. Subscribing to realtime streams.",
    );

    AuditService.instance.init();

    _groupsSub = SupabaseService.instance.watchGroups().listen(
      (data) {
        _groups.clear();
        _groups.addAll(data);
        _groupsStream.add(_groups);
        debugPrint(
          "SecureDbService: Realtime groups update (${data.length} groups).",
        );
      },
      onError: (e) {
        debugPrint(
          "SecureDbService: Realtime stream timeout/error — switching to REST polling fallback. ($e)",
        );
        _cancelSupabaseStreams();
        // Use REST polling every 30s instead of falling to offline mock
        _initRestPollingFallback();
      },
      cancelOnError: true,
    );

    _filesSub = SupabaseService.instance.watchFiles().listen(
      (data) {
        _files.clear();
        _files.addAll(data);
        _filesStream.add(_files);
      },
      onError: (e) {
        debugPrint(
          "SecureDbService: watchFiles realtime error — polling fallback already active.",
        );
        _filesSub?.cancel();
        _filesSub = null;
      },
      cancelOnError: true,
    );
  }

  void _cancelSupabaseStreams() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _filesSub?.cancel();
    _filesSub = null;
    AuditService.instance.cancelStreams();
    _pollTimer?.cancel();
    _pollTimer = null;
    debugPrint("SecureDbService: All Supabase subscriptions cancelled.");
  }

  /// REST polling fallback — used when Supabase Realtime WebSocket times out.
  /// Fetches fresh data from Supabase via HTTP every 30 seconds.
  /// This is enough for the app to show real data without realtime updates.
  void _initRestPollingFallback() {
    debugPrint("SecureDbService: Starting REST polling fallback (every 30s).");
    // Do an immediate fetch, then poll every 30s
    _fetchFromRest();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchFromRest();
    });
  }

  Future<void> _fetchFromRest() async {
    try {
      final client = Supabase.instance.client;

      // Fetch groups
      final groupsResp = await client
          .from('study_groups')
          .select()
          .order('created_at', ascending: false);
      final parsed = groupsResp.map((m) {
        final levelStr = m['security_level'] as String? ?? 'encrypted';
        final level = SecurityLevel.values.firstWhere(
          (e) => e.name == levelStr.toLowerCase(),
          orElse: () => SecurityLevel.encrypted,
        );
        final rawTime = m['last_activity'] ?? m['created_at'];
        final time = rawTime != null
            ? DateTime.parse(rawTime as String)
            : DateTime.now();
        return StudyGroup(
          id: m['id'] as String,
          name: m['name'] as String,
          description: m['description'] as String? ?? '',
          securityLevel: level,
          members: const [],
          fileCount: m['file_count'] as int? ?? 0,
          lastActivity: time,
          isWatermarkEnabled: m['is_watermark_enabled'] as bool? ?? true,
          inviteCode: m['invite_code'] as String?,
        );
      }).toList();
      _groups.clear();
      _groups.addAll(parsed);
      _groupsStream.add(_groups);
      debugPrint(
        "SecureDbService: REST poll — ${parsed.length} groups loaded.",
      );

      // Fetch files
      final filesResp = await client
          .from('secure_files')
          .select()
          .order('uploaded_at', ascending: false);
      final Map<String, List<GroupFile>> filesMap = {};
      for (final row in filesResp) {
        final typeStr = row['type'] as String? ?? 'pdf';
        final fileType = FileType.values.firstWhere(
          (e) => e.name == typeStr.toLowerCase(),
          orElse: () => FileType.pdf,
        );
        final statusStr = row['security_status'] as String? ?? 'secured';
        final status = FileSecurityStatus.values.firstWhere(
          (e) => e.name == statusStr.toLowerCase(),
          orElse: () => FileSecurityStatus.secured,
        );
        final rawTime = row['uploaded_at'];
        final time = rawTime != null
            ? DateTime.parse(rawTime as String)
            : DateTime.now();
        final file = GroupFile(
          id: row['id'] as String,
          name: row['name'] as String,
          type: fileType,
          groupId: row['group_id'] as String,
          uploadedByName: row['uploaded_by_name'] as String? ?? 'Anonymous',
          uploadedByInitials: row['uploaded_by_initials'] as String? ?? 'AN',
          uploadedAt: time,
          sizeBytes: row['size_bytes'] as int? ?? 0,
          isWatermarked: row['is_watermarked'] as bool? ?? true,
          isPinned: row['is_pinned'] as bool? ?? false,
          securityStatus: status,
        );
        final key = row['encryption_key_base64'] as String?;
        final iv = row['encryption_iv_base64'] as String?;
        if (key != null && iv != null) {
          registerCredentials(file.id, key, iv);
        }
        filesMap.putIfAbsent(file.groupId, () => []).add(file);
      }
      _files.clear();
      _files.addAll(filesMap);
      _filesStream.add(_files);

      // Fetch audit logs (delegated)
      final logsResp = await client
          .from('audit_logs')
          .select('created_at, event, status')
          .order('created_at', ascending: false)
          .limit(50);
      final logsParsed = logsResp.map((row) {
        final timeStr = row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String).toLocal().toIso8601String().substring(11, 19)
            : 'Now';
        return {
          'time': timeStr,
          'event': row['event'] as String? ?? '',
          'status': row['status'] as String? ?? '',
        };
      }).toList();
      AuditService.instance.handleRestPollLogs(logsParsed);
    } catch (e) {
      debugPrint("SecureDbService: REST poll error: $e");
    }
  }

  Future<void> _initMockFallback() async {
    // Only run once — if files are already populated, skip
    if (_files.isNotEmpty) {
      _groupsStream.add(_groups);
      _filesStream.add(_files);
      return;
    }

    // Populate default files from mock data with encryption simulation
    for (final group in _groups.toList()) {
      final defaultFiles = MockGroupsData.filesForGroup(group.id).toList();
      _files[group.id] = defaultFiles;

      for (final file in defaultFiles) {
        final key = CryptographyService.generateSymmetricKey();
        final iv = CryptographyService.generateIV();
        final dummyContent = Uint8List.fromList(
          'Decrypted secure cryptographic content block for file: ${file.name}. This sensitive data resides only in volatile memory.'
              .codeUnits,
        );
        final encryptedBytes = await CryptographyService.encryptBytes(
          dummyContent,
          key,
          iv,
        );
        _encryptedStorageBucket[file.id] = encryptedBytes;
        _fileKeys[file.id] = key;
        _fileIVs[file.id] = iv;
      }
    }
    debugPrint(
      "SecureDbService: Mock fallback data initialized (${_groups.length} groups, ${_files.values.fold(0, (a, b) => a + b.length)} files).",
    );
  }

  // ─── Stream / Cache Getters ────────────────────────────────────────────────

  Stream<List<StudyGroup>> watchGroups() {
    return Stream.multi((controller) {
      controller.add(List<StudyGroup>.unmodifiable(_groups));
      final sub = _groupsStream.stream.listen(
        (data) => controller.add(List<StudyGroup>.unmodifiable(data)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<Map<String, List<GroupFile>>> watchFiles() {
    return Stream.multi((controller) {
      controller.add(
        Map<String, List<GroupFile>>.unmodifiable(
          _files.map((k, v) => MapEntry(k, List<GroupFile>.unmodifiable(v))),
        ),
      );
      final sub = _filesStream.stream.listen(
        (data) => controller.add(
          Map<String, List<GroupFile>>.unmodifiable(
            data.map((k, v) => MapEntry(k, List<GroupFile>.unmodifiable(v))),
          ),
        ),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<List<Map<String, String>>> watchAuditLogs() => AuditService.instance.watchAuditLogs();

  List<StudyGroup> get groups => _groups;
  Map<String, List<GroupFile>> get files => _files;
  List<Map<String, String>> get auditLogs => AuditService.instance.auditLogs;

  // ─── Key Registration Hooks ───────────────────────────────────────────────

  /// Registers symmetric keys for decrypting streams in memory.
  void registerCredentials(String fileId, String key, String iv) {
    _fileKeys[fileId] = key;
    _fileIVs[fileId] = iv;
  }

  /// Retrieves cached key for a given file.
  String? getFileKey(String fileId) => _fileKeys[fileId];

  /// Retrieves cached IV for a given file.
  String? getFileIV(String fileId) => _fileIVs[fileId];

  // ─── Database Mutations ────────────────────────────────────────────────────

  Future<void> createGroup(StudyGroup group) async {
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.createGroup(group);
      return;
    }

    _groups.insert(0, group);
    _files[group.id] = [];

    // Create auto-generated notes for the group in mock offline mode
    await _createMockAutoGeneratedNote(
      groupId: group.id,
      title: 'Welcome to ${group.name}',
      content: '# Welcome to ${group.name}!\n\n'
          'We are excited to have you in this secure enclave workspace. Here, you can share sensitive lecture notes, '
          'past exams, and research papers with complete confidence.\n\n'
          '## Quick Tips for Group Members:\n'
          '1. **Confidential Sharing**: All documents uploaded here are end-to-end encrypted locally on your device '
          'before they reach Supabase Storage.\n'
          '2. **Access Control**: Only verified group members can access and decrypt these files.\n'
          '3. **Spyglass Protection**: Click \'REVEAL\' on any document to open it in the secure Spyglass Viewer, '
          'which protects it against screenshots, screen recording, and unauthorized inspection.',
    );

    await _createMockAutoGeneratedNote(
      groupId: group.id,
      title: 'NO SUS Security Features',
      content: '# NO SUS — Advanced Security Features\n\n'
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
          'ensuring full team accountability.',
    );

    _groupsStream.add(_groups);
    _filesStream.add(_files);
    logEvent(
      'Created study group "${group.name}" with level ${group.securityLevel.name.toUpperCase()}',
      'SUCCESS',
    );
  }

  Future<void> _createMockAutoGeneratedNote({
    required String groupId,
    required String title,
    required String content,
  }) async {
    final fileId = 'sec_gen_${groupId}_${title.hashCode.abs()}';
    final key = CryptographyService.generateSymmetricKey();
    final iv = CryptographyService.generateIV();
    final rawBytes = Uint8List.fromList(content.codeUnits);

    try {
      final encryptedBytes = await CryptographyService.encryptBytes(rawBytes, key, iv);
      _encryptedStorageBucket[fileId] = encryptedBytes;
      _fileKeys[fileId] = key;
      _fileIVs[fileId] = iv;
    } catch (_) {}

    final newFile = GroupFile(
      id: fileId,
      name: title,
      type: FileType.markdown,
      groupId: groupId,
      uploadedByName: 'Enclave Admin',
      uploadedByInitials: 'EA',
      uploadedAt: DateTime.now(),
      sizeBytes: rawBytes.length,
      isWatermarked: true,
      isPinned: true,
      securityStatus: FileSecurityStatus.secured,
    );

    final list = _files[groupId] ?? [];
    list.add(newFile);
    _files[groupId] = list;
  }

  Future<void> deleteFile(String groupId, String fileId) async {
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.deleteFile(fileId);
      _fileKeys.remove(fileId);
      _fileIVs.remove(fileId);
      return;
    }

    final list = _files[groupId] ?? [];
    final itemIdx = list.indexWhere((f) => f.id == fileId);
    String fileName = fileId;
    if (itemIdx != -1) {
      fileName = list[itemIdx].name;
      list.removeAt(itemIdx);
    }
    _files[groupId] = list;

    // Purge keys and bytes from storage
    _encryptedStorageBucket.remove(fileId);
    _fileKeys.remove(fileId);
    _fileIVs.remove(fileId);

    _filesStream.add(_files);
    logEvent('Deleted secure file "$fileName" from group $groupId', 'INFO');
  }

  Future<void> togglePin(String groupId, String fileId) async {
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.togglePin(fileId);
      return;
    }

    final list = _files[groupId] ?? [];
    final idx = list.indexWhere((f) => f.id == fileId);
    if (idx != -1) {
      final f = list[idx];
      list[idx] = GroupFile(
        id: f.id,
        name: f.name,
        type: f.type,
        groupId: f.groupId,
        uploadedByName: f.uploadedByName,
        uploadedByInitials: f.uploadedByInitials,
        uploadedAt: f.uploadedAt,
        sizeBytes: f.sizeBytes,
        isWatermarked: f.isWatermarked,
        isPinned: !f.isPinned,
        securityStatus: f.securityStatus,
      );
      _files[groupId] = list;
      _filesStream.add(_files);
    }
  }

  /// Handles secure file upload with dynamic routing
  Future<void> uploadFile({
    required String groupId,
    required String name,
    required FileType type,
    required Uint8List rawBytes,
    required String uploaderName,
    required String uploaderInitials,
    required Function(double) onProgress,
  }) async {
    // A. Generate secure AES key and IV
    final key = CryptographyService.generateSymmetricKey();
    final iv = CryptographyService.generateIV();

    // B. Encrypt file in-memory (size limited to 10MB)
    final encryptedBytes = await CryptographyService.encryptBytes(rawBytes, key, iv);

    // C. Simulate upload stream progress
    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      onProgress(i / 10.0);
    }

    final fileId = 'sec_${DateTime.now().millisecondsSinceEpoch}';

    if (SupabaseService.instance.isReachable) {
      final gDriveId = await SupabaseService.instance.uploadStorageFile(
        fileId,
        encryptedBytes,
      );
      if (gDriveId == null) {
        throw Exception("Failed to upload to Google Drive proxy");
      }

      final newFile = GroupFile(
        id: gDriveId,
        name: name,
        type: type,
        groupId: groupId,
        uploadedByName: uploaderName,
        uploadedByInitials: uploaderInitials,
        uploadedAt: DateTime.now(),
        sizeBytes: rawBytes.length,
        isWatermarked: true,
        securityStatus: FileSecurityStatus.secured,
      );

      await SupabaseService.instance.saveFileMetadata(
        file: newFile,
        key: key,
        iv: iv,
      );

      // Register key/IV in cache
      registerCredentials(gDriveId, key, iv);
      return;
    }

    // D. Persist encrypted payload in cloud storage bucket (mock fallback)
    _encryptedStorageBucket[fileId] = encryptedBytes;
    _fileKeys[fileId] = key;
    _fileIVs[fileId] = iv;

    // E. Save metadata in DB collection (mock fallback)
    final newFile = GroupFile(
      id: fileId,
      name: name,
      type: type,
      groupId: groupId,
      uploadedByName: uploaderName,
      uploadedByInitials: uploaderInitials,
      uploadedAt: DateTime.now(),
      sizeBytes: rawBytes.length,
      isWatermarked: true,
      securityStatus: FileSecurityStatus.secured,
    );

    final list = _files[groupId] ?? [];
    list.insert(0, newFile);
    _files[groupId] = list;

    _filesStream.add(_files);
    logEvent(
      'Successfully encrypted and uploaded "$name" (${rawBytes.length} bytes)',
      'SUCCESS',
    );
  }

  /// Fetches the encrypted payload from cloud storage bucket and decrypts it inside a RAM buffer.
  Future<Uint8List?> downloadAndDecryptFile(String fileId) async {
    final encrypted = _encryptedStorageBucket[fileId];
    final key = _fileKeys[fileId];
    final iv = _fileIVs[fileId];

    if (encrypted == null || key == null || iv == null) {
      return null;
    }

    // Decrypt directly into volatile buffer
    return await CryptographyService.decryptBytes(encrypted, key, iv);
  }

  /// Extracts the Google Drive file ID from a URL.
  String? extractGoogleDriveFileId(String url) {
    // Regex to match typical Google Drive URL file IDs
    // e.g., /file/d/FILE_ID/... or ?id=FILE_ID
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

    // If the input doesn't look like a URL, assume it might be a raw file ID
    if (!url.contains('/') && url.length > 10) {
      return url;
    }

    return null;
  }

  /// Links an existing Google Drive file that is shared (or public).
  Future<void> addGoogleDriveLink({
    required String groupId,
    required String name,
    required FileType type,
    required String driveUrl,
    required String uploaderName,
    required String uploaderInitials,
  }) async {
    final gDriveId = extractGoogleDriveFileId(driveUrl);
    if (gDriveId == null || gDriveId.isEmpty) {
      throw Exception("Invalid Google Drive URL. Could not parse file ID.");
    }

    if (SupabaseService.instance.isReachable) {
      final newFile = GroupFile(
        id: gDriveId,
        name: name,
        type: type,
        groupId: groupId,
        uploadedByName: uploaderName,
        uploadedByInitials: uploaderInitials,
        uploadedAt: DateTime.now(),
        sizeBytes: 0,
        isWatermarked: true,
        securityStatus: FileSecurityStatus.secured,
      );

      // Save metadata with empty credentials
      await SupabaseService.instance.saveFileMetadata(
        file: newFile,
        key: '',
        iv: '',
      );

      logEvent(
        'Linked shared Google Drive file "$name" ($gDriveId)',
        'SUCCESS',
      );
      return;
    }

    // Mock Offline mode fallback
    final newFile = GroupFile(
      id: gDriveId,
      name: name,
      type: type,
      groupId: groupId,
      uploadedByName: uploaderName,
      uploadedByInitials: uploaderInitials,
      uploadedAt: DateTime.now(),
      sizeBytes: 1024 * 1024,
      isWatermarked: true,
      securityStatus: FileSecurityStatus.secured,
    );

    final list = _files[groupId] ?? [];
    list.insert(0, newFile);
    _files[groupId] = list;

    _filesStream.add(_files);
    logEvent(
      'Linked shared Google Drive file "$name" (Offline Mock)',
      'SUCCESS',
    );
  }

  void logEvent(String event, String status) => AuditService.instance.logEvent(event, status);

  String _mockUserNote =
      "Welcome to the NO SUS Secure Workspace!\n\n"
      "Quick Tutorial on Groups:\n"
      "1. Open the 'Groups' tab from the bottom nav.\n"
      "2. Tap the '+' icon to create a secure study group.\n"
      "3. Share the invite code with classmates.\n"
      "4. Upload notes — they are E2E encrypted locally.\n"
      "5. Use 'REVEAL' to read in our screenshot-proof viewer.";

  bool _isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<String> fetchUserNote(String userId) async {
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      return await SupabaseService.instance.fetchUserNote(userId);
    }
    return _mockUserNote;
  }

  Future<void> saveUserNote(String userId, String noteText) async {
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      await SupabaseService.instance.saveUserNote(userId, noteText);
      return;
    }
    _mockUserNote = noteText;
  }

  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async => await FocusService.instance.fetchFocusLogs(userId);
  Future<void> incrementFocusMinutes(String userId, int minutes) async => await FocusService.instance.incrementFocusMinutes(userId, minutes);
  Future<Map<DateTime, int>> fetchAuditLogCounts() async => await AuditService.instance.fetchAuditLogCounts();

  /// Cryptographic Key Rotation operation.
  /// Downloads, decrypts, re-encrypts, and updates metadata in the database/storage.
  Future<void> rotateWorkspaceKeys() async {
    if (SupabaseService.instance.isReachable) {
      final client = Supabase.instance.client;
      // 1. Fetch all files from database
      final filesResponse = await client
          .from('secure_files')
          .select(
            'id, group_id, name, encryption_key_base64, encryption_iv_base64',
          );

      int rotatedCount = 0;
      for (final row in filesResponse as List) {
        final fileId = row['id'] as String;
        final oldKey = row['encryption_key_base64'] as String?;
        final oldIv = row['encryption_iv_base64'] as String?;

        // Skip external files
        if (oldKey == null ||
            oldIv == null ||
            oldKey.isEmpty ||
            oldIv.isEmpty) {
          continue;
        }

        // 2. Download from storage
        final encryptedBytes = await client.storage
            .from('secure-files')
            .download(fileId);

        // 3. Decrypt
        final decryptedBytes = await CryptographyService.decryptBytes(
          encryptedBytes,
          oldKey,
          oldIv,
          );

        // 4. Generate new
        final newKey = CryptographyService.generateSymmetricKey();
        final newIv = CryptographyService.generateIV();

        // 5. Encrypt with new
        final newEncryptedBytes = await CryptographyService.encryptBytes(
          decryptedBytes,
          newKey,
          newIv,
        );

        // 6. Overwrite in storage
        try {
          await client.storage.from('secure-files').remove([fileId]);
        } catch (_) {}
        await client.storage
            .from('secure-files')
            .uploadBinary(fileId, newEncryptedBytes);

        // 7. Update database row
        await client
            .from('secure_files')
            .update({
              'encryption_key_base64': newKey,
              'encryption_iv_base64': newIv,
            })
            .eq('id', fileId);

        // 8. Update cache
        registerCredentials(fileId, newKey, newIv);
        rotatedCount++;
      }

      logEvent(
        'Rotated workspace session encryption keys for $rotatedCount non-external documents',
        'SECURITY',
      );
      return;
    }

    // Mock Offline Mode:
    int rotatedCount = 0;
    for (final groupId in _files.keys) {
      final list = _files[groupId] ?? [];
      for (final file in list) {
        final fileId = file.id;
        final oldKey = _fileKeys[fileId];
        final oldIv = _fileIVs[fileId];

        if (oldKey == null ||
            oldIv == null ||
            oldKey.isEmpty ||
            oldIv.isEmpty) {
          continue;
        }

        final encrypted = _encryptedStorageBucket[fileId];
        if (encrypted == null) continue;

        // Decrypt
        final decryptedBytes = await CryptographyService.decryptBytes(
          encrypted,
          oldKey,
          oldIv,
        );

        // Generate new
        final newKey = CryptographyService.generateSymmetricKey();
        final newIv = CryptographyService.generateIV();

        // Encrypt new
        final newEncryptedBytes = await CryptographyService.encryptBytes(
          decryptedBytes,
          newKey,
          newIv,
        );

        // Save
        _encryptedStorageBucket[fileId] = newEncryptedBytes;
        _fileKeys[fileId] = newKey;
        _fileIVs[fileId] = newIv;
        rotatedCount++;
      }
    }

    logEvent(
      'Rotated workspace session encryption keys for $rotatedCount non-external documents (Offline Mock)',
      'SECURITY',
    );
  }

  // Volatile cache for active user profile
  Map<String, String> _profileCache = {};

  /// Public read-only snapshot of the in-memory profile cache.
  /// Used by onboarding to migrate temp_user identity to the real account.
  Map<String, String> get cachedProfile => Map.unmodifiable(_profileCache);

  Future<Map<String, String>> fetchProfile(
    String userId,
    String userEmail,
  ) async {
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      final data = await SupabaseService.instance.fetchProfile(userId);
      if (data.isNotEmpty) {
        final defaultName = userEmail.isNotEmpty
            ? (userEmail.length > 7 ? userEmail.substring(0, 7) : userEmail)
            : 'Scholar';
        _profileCache = {
          'displayName':
              data['display_name'] as String? ?? defaultName,
          'avatarColorStart':
              data['avatar_color_start'] as String? ?? 'FF0072FF',
          'avatarColorEnd': data['avatar_color_end'] as String? ?? 'FF00F2FE',
          'onboardingCompleted': (data['onboarding_completed'] ?? false).toString(),
        };
        return _profileCache;
      }
    }

    // Offline / Fallback default
    if (_profileCache.isEmpty) {
      final defaultName = userEmail.isNotEmpty
          ? (userEmail.length > 7 ? userEmail.substring(0, 7) : userEmail)
          : 'Enclave Scholar';
      _profileCache = {
        'displayName': defaultName,
        'avatarColorStart': 'FF0072FF',
        'avatarColorEnd': 'FF00F2FE',
        'onboardingCompleted': 'false',
      };
    }
    return _profileCache;
  }

  Future<void> saveProfile({
    required String userId,
    required String email,
    required String displayName,
    required String avatarColorStart,
    required String avatarColorEnd,
    bool onboardingCompleted = true,
  }) async {
    _profileCache = {
      'displayName': displayName,
      'avatarColorStart': avatarColorStart,
      'avatarColorEnd': avatarColorEnd,
      'onboardingCompleted': onboardingCompleted.toString(),
    };
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      await SupabaseService.instance.saveProfile(
        userId: userId,
        email: email,
        displayName: displayName,
        avatarColorStart: avatarColorStart,
        avatarColorEnd: avatarColorEnd,
        onboardingCompleted: onboardingCompleted,
      );
    }
  }
}
