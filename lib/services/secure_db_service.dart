import 'dart:async';
import 'package:flutter/foundation.dart';
import '../features/groups/domain/models/study_group.dart';
import '../features/groups/models/group_file.dart';
import '../features/groups/data/mock_groups_data.dart';
import 'cryptography_service.dart';
import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final List<Map<String, String>> _auditLogs = [
    {'time': 'Now', 'event': 'Workspace session initiated', 'status': 'INFO'},
  ];
  bool _onboardingCompleted = false;

  bool isOnboardingCompleted() => _onboardingCompleted;
  void completeOnboarding() {
    _onboardingCompleted = true;
  }

  // In-memory encrypted binary vaults mimicking AWS S3 or Google Cloud Storage buckets
  final Map<String, Uint8List> _encryptedStorageBucket = {};
  final Map<String, String> _fileKeys = {}; // fileId -> keyBase64
  final Map<String, String> _fileIVs = {}; // fileId -> ivBase64

  // StreamControllers to publish real-time database updates for local fallback
  final StreamController<List<StudyGroup>> _groupsStream =
      StreamController<List<StudyGroup>>.broadcast();
  final StreamController<Map<String, List<GroupFile>>> _filesStream =
      StreamController<Map<String, List<GroupFile>>>.broadcast();
  final StreamController<List<Map<String, String>>> _auditLogsStream =
      StreamController<List<Map<String, String>>>.broadcast();

  // Supabase stream subscription handles — stored so we can cancel them on failure
  StreamSubscription? _groupsSub;
  StreamSubscription? _filesSub;
  StreamSubscription? _auditLogsSub;

  void _init() {
    if (SupabaseService.instance.isReachable) {
      _initSupabaseStreams();
      return;
    }
    _initMockFallback();
  }

  void _initSupabaseStreams() {
    debugPrint(
      "SecureDbService: Supabase active. Subscribing to realtime streams.",
    );

    _groupsSub = SupabaseService.instance.watchGroups().listen(
      (data) {
        _groups.clear();
        _groups.addAll(data);
        _groupsStream.add(_groups);
      },
      onError: (e) {
        debugPrint(
          "SecureDbService: Supabase stream error — cancelling all subscriptions and switching to mock fallback.",
        );
        _cancelSupabaseStreams();
        _initMockFallback();
      },
      cancelOnError: true, // Cancel THIS subscription on error
    );

    _filesSub = SupabaseService.instance.watchFiles().listen(
      (data) {
        _files.clear();
        _files.addAll(data);
        _filesStream.add(_files);
      },
      onError: (e) {
        debugPrint(
          "SecureDbService: watchFiles stream error — switching to mock fallback.",
        );
        _cancelSupabaseStreams();
        _initMockFallback();
      },
      cancelOnError: true,
    );

    _auditLogsSub = SupabaseService.instance.watchAuditLogs().listen(
      (data) {
        _auditLogs.clear();
        _auditLogs.addAll(data);
        _auditLogsStream.add(_auditLogs);
      },
      onError: (e) {
        debugPrint(
          "SecureDbService: watchAuditLogs stream error — switching to mock fallback.",
        );
        _cancelSupabaseStreams();
        _initMockFallback();
      },
      cancelOnError: true,
    );
  }

  void _cancelSupabaseStreams() {
    _groupsSub?.cancel();
    _filesSub?.cancel();
    _auditLogsSub?.cancel();
    _groupsSub = null;
    _filesSub = null;
    _auditLogsSub = null;
    debugPrint(
      "SecureDbService: All Supabase subscriptions cancelled. Running on mock data.",
    );
  }

  void _initMockFallback() {
    // Only run once — if files are already populated, skip
    if (_files.isNotEmpty) {
      _groupsStream.add(_groups);
      _filesStream.add(_files);
      _auditLogsStream.add(_auditLogs);
      return;
    }

    // Populate default files from mock data with encryption simulation
    for (final group in _groups) {
      final defaultFiles = MockGroupsData.filesForGroup(group.id);
      _files[group.id] = defaultFiles;

      for (final file in defaultFiles) {
        final key = CryptographyService.generateSymmetricKey();
        final iv = CryptographyService.generateIV();
        final dummyContent = Uint8List.fromList(
          'Decrypted secure cryptographic content block for file: ${file.name}. This sensitive data resides only in volatile memory.'
              .codeUnits,
        );
        final encryptedBytes = CryptographyService.encryptBytes(
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
      controller.add(Map<String, List<GroupFile>>.unmodifiable(
        _files.map((k, v) => MapEntry(k, List<GroupFile>.unmodifiable(v))),
      ));
      final sub = _filesStream.stream.listen(
        (data) => controller.add(Map<String, List<GroupFile>>.unmodifiable(
          data.map((k, v) => MapEntry(k, List<GroupFile>.unmodifiable(v))),
        )),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  Stream<List<Map<String, String>>> watchAuditLogs() {
    return Stream.multi((controller) {
      controller.add(List<Map<String, String>>.unmodifiable(_auditLogs));
      final sub = _auditLogsStream.stream.listen(
        (data) => controller.add(List<Map<String, String>>.unmodifiable(data)),
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  List<StudyGroup> get groups => _groups;
  Map<String, List<GroupFile>> get files => _files;
  List<Map<String, String>> get auditLogs => _auditLogs;

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
    _groupsStream.add(_groups);
    _filesStream.add(_files);
    logEvent(
      'Created study group "${group.name}" with level ${group.securityLevel.name.toUpperCase()}',
      'SUCCESS',
    );
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

    // B. Encrypt file in-memory
    final encryptedBytes = CryptographyService.encryptBytes(rawBytes, key, iv);

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
  Uint8List? downloadAndDecryptFile(String fileId) {
    final encrypted = _encryptedStorageBucket[fileId];
    final key = _fileKeys[fileId];
    final iv = _fileIVs[fileId];

    if (encrypted == null || key == null || iv == null) {
      return null;
    }

    // Decrypt directly into volatile buffer
    return CryptographyService.decryptBytes(encrypted, key, iv);
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

  void logEvent(String event, String status) {
    if (SupabaseService.instance.isReachable) {
      SupabaseService.instance.logEvent(event, status);
      return;
    }

    final now = DateTime.now();
    final timeStr = '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}';
    _auditLogs.insert(0, {'time': timeStr, 'event': event, 'status': status});
    _auditLogsStream.add(_auditLogs);
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  String _mockUserNote = "Research notes on AES-GCM authentication tags:\n"
      "- Tag length: 128 bits recommended.\n"
      "- Never reuse the initialization vector (IV) under the same key.\n"
      "- Ensure constant-time tag comparison to prevent timing attacks.";

  Future<String> fetchUserNote(String userId) async {
    if (SupabaseService.instance.isReachable) {
      return await SupabaseService.instance.fetchUserNote(userId);
    }
    return _mockUserNote;
  }

  Future<void> saveUserNote(String userId, String noteText) async {
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.saveUserNote(userId, noteText);
      return;
    }
    _mockUserNote = noteText;
  }

  final Map<String, int> _mockFocusLogs = {}; // dateString -> minutes

  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async {
    if (SupabaseService.instance.isReachable) {
      return await SupabaseService.instance.fetchFocusLogs(userId);
    }
    // Fallback to mock data for the last 7 days
    final Map<DateTime, int> logs = {};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);
      final dateStr = day.toIso8601String().substring(0, 10);
      
      final weekday = day.weekday;
      final int defaultMinutes;
      switch (weekday) {
        case 1: defaultMinutes = (4.5 * 60).round(); break;
        case 2: defaultMinutes = (6.0 * 60).round(); break;
        case 3: defaultMinutes = (3.2 * 60).round(); break;
        case 4: defaultMinutes = (8.0 * 60).round(); break;
        case 5: defaultMinutes = (5.5 * 60).round(); break;
        case 6: defaultMinutes = (2.0 * 60).round(); break;
        case 7: defaultMinutes = (4.0 * 60).round(); break;
        default: defaultMinutes = 0;
      }
      
      final minutes = _mockFocusLogs[dateStr] ?? defaultMinutes;
      logs[dayKey] = minutes;
    }
    return logs;
  }

  Future<void> incrementFocusMinutes(String userId, int minutes) async {
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.incrementFocusMinutes(userId, minutes);
      return;
    }
    final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
    final current = _mockFocusLogs[todayStr] ?? 0;
    _mockFocusLogs[todayStr] = current + minutes;
  }

  Future<Map<DateTime, int>> fetchAuditLogCounts() async {
    if (SupabaseService.instance.isReachable) {
      return await SupabaseService.instance.fetchAuditLogCounts();
    }
    // Mock mode:
    final Map<DateTime, int> counts = {};
    final now = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dayKey = DateTime(day.year, day.month, day.day);
      final weekday = day.weekday;
      final int defaultScans;
      switch (weekday) {
        case 1: defaultScans = 12; break;
        case 2: defaultScans = 18; break;
        case 3: defaultScans = 8; break;
        case 4: defaultScans = 24; break;
        case 5: defaultScans = 14; break;
        case 6: defaultScans = 4; break;
        case 7: defaultScans = 10; break;
        default: defaultScans = 0;
      }
      counts[dayKey] = defaultScans;
    }
    // For today, count in-memory logs
    final todayKey = DateTime(now.year, now.month, now.day);
    counts[todayKey] = _auditLogs.length;
    return counts;
  }

  /// Cryptographic Key Rotation operation.
  /// Downloads, decrypts, re-encrypts, and updates metadata in the database/storage.
  Future<void> rotateWorkspaceKeys() async {
    if (SupabaseService.instance.isReachable) {
      final client = Supabase.instance.client;
      // 1. Fetch all files from database
      final filesResponse = await client
          .from('secure_files')
          .select('id, group_id, name, encryption_key_base64, encryption_iv_base64');
      
      int rotatedCount = 0;
      for (final row in filesResponse as List) {
        final fileId = row['id'] as String;
        final oldKey = row['encryption_key_base64'] as String?;
        final oldIv = row['encryption_iv_base64'] as String?;
        
        // Skip external files
        if (oldKey == null || oldIv == null || oldKey.isEmpty || oldIv.isEmpty) {
          continue;
        }
        
        // 2. Download from storage
        final encryptedBytes = await client.storage.from('secure-files').download(fileId);
        
        // 3. Decrypt
        final decryptedBytes = CryptographyService.decryptBytes(encryptedBytes, oldKey, oldIv);
        
        // 4. Generate new
        final newKey = CryptographyService.generateSymmetricKey();
        final newIv = CryptographyService.generateIV();
        
        // 5. Encrypt with new
        final newEncryptedBytes = CryptographyService.encryptBytes(decryptedBytes, newKey, newIv);
        
        // 6. Overwrite in storage
        try {
          await client.storage.from('secure-files').remove([fileId]);
        } catch (_) {}
        await client.storage.from('secure-files').uploadBinary(fileId, newEncryptedBytes);
        
        // 7. Update database row
        await client.from('secure_files').update({
          'encryption_key_base64': newKey,
          'encryption_iv_base64': newIv,
        }).eq('id', fileId);
        
        // 8. Update cache
        registerCredentials(fileId, newKey, newIv);
        rotatedCount++;
      }
      
      logEvent('Rotated workspace session encryption keys for $rotatedCount non-external documents', 'SECURITY');
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
        
        if (oldKey == null || oldIv == null || oldKey.isEmpty || oldIv.isEmpty) {
          continue;
        }
        
        final encrypted = _encryptedStorageBucket[fileId];
        if (encrypted == null) continue;
        
        // Decrypt
        final decryptedBytes = CryptographyService.decryptBytes(encrypted, oldKey, oldIv);
        
        // Generate new
        final newKey = CryptographyService.generateSymmetricKey();
        final newIv = CryptographyService.generateIV();
        
        // Encrypt new
        final newEncryptedBytes = CryptographyService.encryptBytes(decryptedBytes, newKey, newIv);
        
        // Save
        _encryptedStorageBucket[fileId] = newEncryptedBytes;
        _fileKeys[fileId] = newKey;
        _fileIVs[fileId] = newIv;
        rotatedCount++;
      }
    }
    
    logEvent('Rotated workspace session encryption keys for $rotatedCount non-external documents (Offline Mock)', 'SECURITY');
  }

  // Volatile cache for active user profile
  Map<String, String> _profileCache = {};

  /// Public read-only snapshot of the in-memory profile cache.
  /// Used by onboarding to migrate temp_user identity to the real account.
  Map<String, String> get cachedProfile => Map.unmodifiable(_profileCache);

  Future<Map<String, String>> fetchProfile(String userId, String userEmail) async {
    if (SupabaseService.instance.isReachable) {
      final data = await SupabaseService.instance.fetchProfile(userId);
      if (data.isNotEmpty) {
        _profileCache = {
          'displayName': data['display_name'] as String? ?? userEmail.split('@').first,
          'avatarColorStart': data['avatar_color_start'] as String? ?? 'FF0072FF',
          'avatarColorEnd': data['avatar_color_end'] as String? ?? 'FF00F2FE',
        };
        return _profileCache;
      }
    }
    
    // Offline / Fallback default
    if (_profileCache.isEmpty) {
      final name = userEmail.contains('@') ? userEmail.split('@').first : 'Enclave Scholar';
      _profileCache = {
        'displayName': name,
        'avatarColorStart': 'FF0072FF',
        'avatarColorEnd': 'FF00F2FE',
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
  }) async {
    _profileCache = {
      'displayName': displayName,
      'avatarColorStart': avatarColorStart,
      'avatarColorEnd': avatarColorEnd,
    };
    if (SupabaseService.instance.isReachable) {
      await SupabaseService.instance.saveProfile(
        userId: userId,
        email: email,
        displayName: displayName,
        avatarColorStart: avatarColorStart,
        avatarColorEnd: avatarColorEnd,
      );
    }
  }
}
