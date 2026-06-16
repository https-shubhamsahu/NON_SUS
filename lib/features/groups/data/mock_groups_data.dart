import '../domain/models/study_group.dart';
import '../models/group_file.dart';

/// Static mock data layer. Replace with API calls by swapping these methods
/// in the Riverpod providers — no widget code changes required.
abstract class MockGroupsData {
  // ─── Members ───────────────────────────────────────────────────────────────

  static const membersAlice = GroupMember(
    id: 'm1',
    name: 'Alice Chen',
    initials: 'AC',
    isAdmin: true,
  );
  static const membersMe = GroupMember(
    id: 'me',
    name: 'You (Sync)',
    initials: 'ME',
  );
  static const membersBob = GroupMember(
    id: 'm2',
    name: 'Bob Smith',
    initials: 'BS',
  );
  static const membersCharlie = GroupMember(
    id: 'm3',
    name: 'Charlie Brown',
    initials: 'CB',
  );
  static const membersDavid = GroupMember(
    id: 'm4',
    name: 'David Miller',
    initials: 'DM',
  );
  static const membersEva = GroupMember(
    id: 'm5',
    name: 'Eva Green',
    initials: 'EG',
  );
  static const membersFiona = GroupMember(
    id: 'm6',
    name: 'Fiona Gallagher',
    initials: 'FG',
    isAdmin: true,
  );

  // ─── Groups ────────────────────────────────────────────────────────────────

  static List<StudyGroup> get groups => [];

  // ─── Files ─────────────────────────────────────────────────────────────────

  static List<GroupFile> filesForGroup(String groupId) {
    return const [];
  }

  // ─── Activity Feed ─────────────────────────────────────────────────────────

  static List<Map<String, String>> activityForGroup(String groupId) {
    return const [];
  }
}
