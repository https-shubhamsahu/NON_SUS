import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/study_group.dart';
import '../models/group_file.dart';
import '../../../services/supabase_service.dart';
import '../presentation/providers/group_dependencies.dart';
import '../../files/domain/models/secure_file_metadata.dart';
import '../../files/presentation/providers/secure_file_providers.dart';

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

  Future<void> joinGroupByName(String name) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final userId = SupabaseService.instance.isReachable ? Supabase.instance.client.auth.currentUser?.id : null;
      if (userId != null) {
        await repo.joinGroupByName(name, userId);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> joinByInviteCode(String inviteCode) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(studyGroupRepositoryProvider);
      final userId = SupabaseService.instance.isReachable ? Supabase.instance.client.auth.currentUser?.id : null;
      if (userId != null) {
        await repo.joinGroupByInviteCode(inviteCode, userId);
      } else {
        throw Exception("You must be logged in to join a group.");
      }
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
    final fileType = metadata.type == SecureFileType.note
        ? FileType.markdown
        : FileType.values.firstWhere(
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
