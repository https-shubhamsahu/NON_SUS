import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/study_group.dart';
import '../models/group_file.dart';
import '../../../services/secure_db_service.dart';
import '../../../services/supabase_service.dart';
import '../presentation/providers/group_dependencies.dart';
import '../../files/domain/models/secure_file_metadata.dart';
import '../../files/presentation/providers/secure_file_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../components/study_chart.dart';

// ─── Search query ─────────────────────────────────────────────────────────────

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

// ─── Groups list ──────────────────────────────────────────────────────────────

class GroupsNotifier extends AsyncNotifier<List<StudyGroup>> {
  StreamSubscription? _sub;

  @override
  Future<List<StudyGroup>> build() async {
    final repo = ref.watch(studyGroupRepositoryProvider);
    _sub?.cancel();
    _sub = repo.watchGroups().listen(
      (data) {
        state = AsyncValue.data(data);
      },
      onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      },
    );
    ref.onDispose(() => _sub?.cancel());

    try {
      return await repo.watchGroups().first;
    } catch (_) {
      return const [];
    }
  }

  Future<void> createGroup(StudyGroup group) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      await repo.createGroup(group);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final groups = await repo.watchGroups().first;
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final groupsProvider = AsyncNotifierProvider<GroupsNotifier, List<StudyGroup>>(
  GroupsNotifier.new,
);

/// Filtered groups based on the current search query.
final filteredGroupsProvider = Provider<AsyncValue<List<StudyGroup>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase().trim();
  final groupsAsync = ref.watch(groupsProvider);

  return groupsAsync.whenData((groups) {
    if (query.isEmpty) return groups;
    return groups
        .where(
          (g) =>
              g.name.toLowerCase().contains(query) ||
              g.description.toLowerCase().contains(query),
        )
        .toList();
  });
});

// ─── Group files ──────────────────────────────────────────────────────────────

class GroupFilesNotifier extends AsyncNotifier<Map<String, List<GroupFile>>> {
  StreamSubscription? _sub;

  @override
  Future<Map<String, List<GroupFile>>> build() async {
    final repo = ref.watch(secureFileRepositoryProvider);
    _sub?.cancel();
    _sub = repo.watchAllFiles().listen(
      (data) {
        final Map<String, List<GroupFile>> filesMap = {};
        for (final file in data) {
          final groupFile = _mapMetadata(file);
          filesMap.putIfAbsent(file.groupId, () => []).add(groupFile);
        }
        state = AsyncValue.data(filesMap);
      },
      onError: (err, stack) {
        state = AsyncValue.error(err, stack);
      },
    );
    ref.onDispose(() => _sub?.cancel());

    try {
      final initialData = await repo.watchAllFiles().first;
      final Map<String, List<GroupFile>> filesMap = {};
      for (final file in initialData) {
        final groupFile = _mapMetadata(file);
        filesMap.putIfAbsent(file.groupId, () => []).add(groupFile);
      }
      return filesMap;
    } catch (_) {
      return const {};
    }
  }

  void addFile(String groupId, GroupFile file) {
    // Left for direct calls/testing, but upload is now handled via uploadProvider
  }

  Future<void> removeFile(String groupId, String fileId) async {
    final repo = ref.read(secureFileRepositoryProvider);
    await repo.deleteFile(groupId, fileId);
  }

  Future<void> togglePin(String groupId, String fileId) async {
    final repo = ref.read(secureFileRepositoryProvider);
    await repo.togglePin(groupId, fileId);
  }

  GroupFile _mapMetadata(SecureFileMetadata metadata) {
    final fileType = FileType.values.firstWhere(
      (e) => e.name == metadata.type.name,
      orElse: () => FileType.pdf,
    );

    final securityStatus = FileSecurityStatus.values.firstWhere(
      (e) => e.name == metadata.status.name,
      orElse: () => FileSecurityStatus.secured,
    );

    final initials = metadata.uploaderName.isNotEmpty && metadata.uploaderName.contains('@')
        ? metadata.uploaderName.split('@').first.substring(0, 2).toUpperCase()
        : metadata.uploaderName.isNotEmpty
            ? metadata.uploaderName.substring(0, 2).toUpperCase()
            : 'AN';

    return GroupFile(
      id: metadata.id,
      name: metadata.name,
      type: fileType,
      groupId: metadata.groupId,
      uploadedByName: metadata.uploaderName,
      uploadedByInitials: initials,
      uploadedAt: metadata.uploadedAt,
      sizeBytes: metadata.sizeBytes,
      isWatermarked: metadata.isWatermarked,
      isPinned: metadata.isPinned,
      securityStatus: securityStatus,
    );
  }
}

final groupFilesProvider =
    AsyncNotifierProvider<GroupFilesNotifier, Map<String, List<GroupFile>>>(
      GroupFilesNotifier.new,
    );

// ─── Upload state ─────────────────────────────────────────────────────────────

enum UploadStage { idle, picking, processing, complete, error }

class UploadState {
  final UploadStage stage;
  final double progress; // 0.0–1.0
  final String? fileName;
  final String? errorMessage;

  const UploadState({
    this.stage = UploadStage.idle,
    this.progress = 0.0,
    this.fileName,
    this.errorMessage,
  });

  UploadState copyWith({
    UploadStage? stage,
    double? progress,
    String? fileName,
    String? errorMessage,
  }) => UploadState(
    stage: stage ?? this.stage,
    progress: progress ?? this.progress,
    fileName: fileName ?? this.fileName,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

class UploadNotifier extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  Future<void> uploadDocument(
    String fileName,
    FileType type,
    String groupId,
    Uint8List rawBytes,
  ) async {
    state = state.copyWith(
      stage: UploadStage.processing,
      fileName: fileName,
      progress: 0,
    );

    try {
      final repo = ref.read(secureFileRepositoryProvider);
      final domainType = SecureFileType.values.firstWhere(
        (e) => e.name == type.name,
        orElse: () => SecureFileType.pdf,
      );

      final currentUser = ref.read(authRepositoryProvider).currentUser;
      final profileVal = ref.read(profileProvider).value;
      final uploaderName = profileVal?.displayName ?? currentUser?.email ?? 'Anonymous';
      final uploaderInitials = uploaderName.isNotEmpty
          ? (uploaderName.contains('@')
              ? uploaderName.split('@').first.substring(0, 2).toUpperCase()
              : uploaderName.substring(0, uploaderName.length >= 2 ? 2 : uploaderName.length).toUpperCase())
          : 'AN';

      await repo.uploadFile(
        groupId: groupId,
        name: fileName,
        type: domainType,
        rawBytes: rawBytes,
        uploaderName: uploaderName,
        uploaderInitials: uploaderInitials,
        onProgress: (prog) {
          state = state.copyWith(progress: prog);
        },
      );

      state = state.copyWith(stage: UploadStage.complete, progress: 1.0);

      // Auto-reset after confirmation display
      await Future.delayed(const Duration(milliseconds: 1400));
      state = const UploadState();
    } catch (e) {
      state = state.copyWith(
        stage: UploadStage.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Compatibility wrapper for UI to trigger simulated secure uploads with raw bytes.
  Future<void> simulateUpload(
    String fileName,
    FileType type,
    String groupId,
  ) async {
    final docTitle = fileName.replaceAll(type.extension, '');
    final docText = _generateMockDocumentText(docTitle, type);
    final docBytes = Uint8List.fromList(utf8.encode(docText));
    await uploadDocument(fileName, type, groupId, docBytes);
  }

  String _generateMockDocumentText(String title, FileType type) {
    if (type == FileType.pdf || type == FileType.markdown) {
      if (title.toLowerCase().contains('proof') ||
          title.toLowerCase().contains('zero') ||
          title.toLowerCase().contains('zkp')) {
        return '''Zero-Knowledge Proofs (ZKP) / Deep Dive & Mathematical Background
A Zero-Knowledge Proof (ZKP) allows a prover to convince a verifier that a statement is true without revealing any information beyond the validity of the statement itself.

Key ZKP Properties & Formal Definition
1. Completeness: If the statement is true, an honest verifier will be convinced by an honest prover.
2. Soundness: If the statement is false, no cheating prover can convince an honest verifier (except with tiny probability).
3. Zero-Knowledge: If the statement is true, no verifier learns anything other than this fact.

Non-Interactive Zero-Knowledge (NIZK)
NIZKs remove the requirement for interaction between the prover and verifier. They typically rely on a Common Reference String (CRS) or a Random Oracle model (e.g., using the Fiat-Shamir heuristic).

Applications in Modern Blockchain and Identity Systems
ZKP protocols are critical in privacy-preserving blockchains, off-chain rollup proofs, and selective disclosure protocols for decentralized identity (DID).''';
      } else if (title.toLowerCase().contains('aes') ||
          title.toLowerCase().contains('crypto') ||
          title.toLowerCase().contains('key') ||
          title.toLowerCase().contains('gcm')) {
        return '''Applied Cryptography / AES-256-GCM Performance & Safety
Advanced Encryption Standard (AES) with Galois/Counter Mode (GCM) provides authenticated symmetric key encryption with hardware-accelerated integrity verification.

Hardware Acceleration Features
1. Intel AES-NI & ARMv8 Cryptography: CPU instruction sets execute rounds of AES in constant time, avoiding cache-timing leaks.
2. Galois Field Multiplier: Acceleration of the GHASH hash over GF(2^128) using carry-less multiplication instructions.
3. Authenticated Encryption: GCM ensures both confidentiality of the payload and verification of the associated data header.

Security Configuration Rules
Always use unique 96-bit Initialization Vectors (IVs) for every single encryption. Never reuse an IV with the same key, as it destroys the authenticity guarantees of GCM completely.''';
      } else if (title.toLowerCase().contains('enclave') ||
          title.toLowerCase().contains('os') ||
          title.toLowerCase().contains('kernel') ||
          title.toLowerCase().contains('hardware')) {
        return '''Secure Enclave Systems / Kernel Isolation & Memory Sandboxing
Hardware-enforced secure enclaves protect critical process memory spaces from privileged OS components, hypervisors, and side-channel snooping.

Architectural Design
1. Microkernel Design: Restricting the Trusted Computing Base (TCB) by running drivers and file systems in unprivileged user space.
2. Physical RAM Encryption: AMD SEV and Intel SGX automatically encrypt data lines to RAM, preventing hardware memory tapping.
3. Context Switch Sandboxing: Strict page table isolation (KPTI) shields kernel page mapping from user-space branch prediction.

Vulnerability Mitigation
By mapping and decrypting study documents exclusively inside in-memory volatile memory enclaves (RAM), we prevent secondary non-volatile storage residual writes.''';
      }
    }

    // Default study notes
    return '''$title / Study Document
This document contains the secure sharing notes package for $title.

Section 1: General Overview
The notes in this document are distributed securely via the Google Drive client proxy. Access permissions are verified using JWT claims dynamically matching study group memberships.

Section 2: Key Guidelines
1. Do not capture snapshots of these materials. Analog leak deterrence watermarks are displayed across the reading canvas.
2. Active reading is enforced: Touch the screen to clear the blur and reveal content.
3. Disposing of this window triggers a memory purge, zero-filling the active enclave byte array buffer immediately.

Section 3: Conclusion & Next Steps
Collaborators must verify notes and update progress within the team study log. All read operations are logged to the audit ledger for accountability.''';
  }

  void reset() => state = const UploadState();
}

final uploadProvider = NotifierProvider<UploadNotifier, UploadState>(
  UploadNotifier.new,
);

// ─── Audit logs ──────────────────────────────────────────────────────────────

class AuditLogsNotifier extends Notifier<List<Map<String, String>>> {
  StreamSubscription? _sub;

  @override
  List<Map<String, String>> build() {
    _sub?.cancel();
    _sub = SecureDbService.instance.watchAuditLogs().listen((data) {
      state = data;
    });
    ref.onDispose(() => _sub?.cancel());

    return SecureDbService.instance.auditLogs;
  }

  void addLog(String event, String status) {
    SecureDbService.instance.logEvent(event, status);
  }
}

final auditLogsProvider =
    NotifierProvider<AuditLogsNotifier, List<Map<String, String>>>(
      AuditLogsNotifier.new,
    );

// ─── Secure Notes ──────────────────────────────────────────────────────────────

class NoteState {
  final String content;
  final bool isSaving;
  const NoteState({required this.content, required this.isSaving});
}

class UserNoteNotifier extends Notifier<NoteState> {
  Timer? _debounceTimer;

  @override
  NoteState build() {
    return const NoteState(content: '', isSaving: false);
  }

  void loadNote(String userId) async {
    final content = await SecureDbService.instance.fetchUserNote(userId);
    state = NoteState(content: content, isSaving: false);
  }

  void updateNote(String newContent) {
    state = NoteState(content: newContent, isSaving: true);
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        await SecureDbService.instance.saveUserNote(user.id, newContent);
      }
      state = NoteState(content: newContent, isSaving: false);
    });
  }
}

final userNoteProvider = NotifierProvider<UserNoteNotifier, NoteState>(
  UserNoteNotifier.new,
);

// ─── Study Focus Session & Timeline ──────────────────────────────────────────

class FocusSessionNotifier extends Notifier<void> {
  Timer? _timer;

  @override
  void build() {
    _startTimer();
    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        SecureDbService.instance.incrementFocusMinutes(user.id, 1).then((_) {
          ref.read(studyTimelineProvider.notifier).refresh();
        });
      }
    });
  }
  
  void addFocusMinutes(int minutes) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      SecureDbService.instance.incrementFocusMinutes(user.id, minutes).then((_) {
        ref.read(studyTimelineProvider.notifier).refresh();
      });
    }
  }
}

final focusSessionProvider = NotifierProvider<FocusSessionNotifier, void>(
  FocusSessionNotifier.new,
);

class StudyTimelineNotifier extends AsyncNotifier<List<StudyDayData>> {
  @override
  Future<List<StudyDayData>> build() async {
    final auth = ref.watch(authStateProvider).value;
    ref.watch(auditLogsProvider);

    final userId = auth?.id ?? 'guest';
    final focusLogs = await SecureDbService.instance.fetchFocusLogs(userId);
    final auditCounts = await SecureDbService.instance.fetchAuditLogCounts();

    final List<StudyDayData> list = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayKey = DateTime(date.year, date.month, date.day);
      
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayName = dayNames[date.weekday - 1];
      
      final focusMinutes = focusLogs[dayKey] ?? 0;
      final hours = focusMinutes / 60.0;
      final scans = auditCounts[dayKey] ?? 0;
      
      list.add(StudyDayData(
        day: dayName,
        hours: double.parse(hours.toStringAsFixed(1)),
        scans: scans,
      ));
    }
    
    return list;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final studyTimelineProvider = AsyncNotifierProvider<StudyTimelineNotifier, List<StudyDayData>>(
  StudyTimelineNotifier.new,
);

final allProfilesProvider = FutureProvider<List<GroupMember>>((ref) async {
  if (SupabaseService.instance.isReachable) {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, email')
          .order('display_name', ascending: true);
      
      final list = <GroupMember>[];
      for (var r in response as List) {
        final id = r['id'] as String;
        final name = r['display_name'] as String? ?? (r['email'] as String? ?? 'Scholar').split('@').first;
        final initials = name.isNotEmpty
            ? name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase()
            : 'SC';
        list.add(GroupMember(
          id: id,
          name: name,
          initials: initials,
          isAdmin: false,
        ));
      }
      
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}
  }
  // Fallback to mock profiles if offline or query fails
  return const [
    GroupMember(id: 'm1', name: 'Alice Chen', initials: 'AC', isAdmin: true),
    GroupMember(id: 'm2', name: 'You (Sync)', initials: 'ME'),
  ];
});
