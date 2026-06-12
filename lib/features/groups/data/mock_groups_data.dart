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

  static List<StudyGroup> get groups => [
        StudyGroup(
          id: 'g1',
          name: 'Cryptography Core',
          description: 'Core cryptographic principles, RSA, and ZKP discussions.',
          securityLevel: SecurityLevel.verified,
          members: const [membersAlice, membersMe, membersBob, membersCharlie, membersDavid],
          fileCount: 1,
          lastActivity: DateTime.now().subtract(const Duration(minutes: 12)),
          isWatermarkEnabled: true,
          inviteCode: 'GRP-9021',
        ),
        StudyGroup(
          id: 'g2',
          name: 'Zero-Knowledge Lab',
          description: 'Advanced studies in zk-SNARKs, zk-STARKs, and commitment schemes.',
          securityLevel: SecurityLevel.encrypted,
          members: const [membersFiona, membersBob, membersCharlie],
          fileCount: 1,
          lastActivity: DateTime.now().subtract(const Duration(hours: 3)),
          isWatermarkEnabled: true,
          inviteCode: 'GRP-3081',
        ),
        StudyGroup(
          id: 'g3',
          name: 'OS Security Research',
          description: 'Microkernel design, SGX/SEV hardware enclaves, and sandboxing.',
          securityLevel: SecurityLevel.encrypted,
          members: const [membersAlice, membersMe, membersCharlie, membersEva, membersDavid],
          fileCount: 1,
          lastActivity: DateTime.now().subtract(const Duration(hours: 1)),
          isWatermarkEnabled: true,
          inviteCode: 'GRP-5542',
        ),
      ];

  // ─── Files ─────────────────────────────────────────────────────────────────

  static List<GroupFile> filesForGroup(String groupId) {
    switch (groupId) {
      case 'g1':
        return [
          GroupFile(
            id: 'f1',
            name: 'RSA Key Generation Deep Dive',
            type: FileType.pdf,
            groupId: 'g1',
            uploadedByName: 'Alice Chen',
            uploadedByInitials: 'AC',
            uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
            sizeBytes: 1536 * 1024,
            isWatermarked: true,
            isPinned: true,
            securityStatus: FileSecurityStatus.secured,
          ),
        ];
      case 'g2':
        return [
          GroupFile(
            id: 'f5',
            name: 'zkSNARK Primer (Groth16)',
            type: FileType.pdf,
            groupId: 'g2',
            uploadedByName: 'Fiona Gallagher',
            uploadedByInitials: 'FG',
            uploadedAt: DateTime.now().subtract(const Duration(days: 4)),
            sizeBytes: 2450 * 1024,
            isWatermarked: true,
            isPinned: false,
            securityStatus: FileSecurityStatus.secured,
          ),
        ];
      case 'g3':
        return [
          GroupFile(
            id: 'f8',
            name: 'SGX Enclave Architecture',
            type: FileType.pdf,
            groupId: 'g3',
            uploadedByName: 'Alice Chen',
            uploadedByInitials: 'AC',
            uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
            sizeBytes: 3120 * 1024,
            isWatermarked: true,
            isPinned: true,
            securityStatus: FileSecurityStatus.secured,
          ),
        ];
      default:
        return const [];
    }
  }

  // ─── Activity Feed ─────────────────────────────────────────────────────────

  static List<Map<String, String>> activityForGroup(String groupId) {
    switch (groupId) {
      case 'g1':
        return [
          {'icon': 'upload', 'text': 'Alice Chen uploaded RSA Key Generation Deep Dive.pdf', 'time': '2 days ago'},
          {'icon': 'member', 'text': 'Charlie Brown joined the group via invite code', 'time': '3 days ago'},
          {'icon': 'pin', 'text': 'Alice Chen pinned RSA Key Generation Deep Dive.pdf', 'time': '2 days ago'},
        ];
      case 'g2':
        return [
          {'icon': 'upload', 'text': 'Fiona Gallagher uploaded zkSNARK Primer (Groth16).pdf', 'time': '4 days ago'},
          {'icon': 'member', 'text': 'Bob Smith joined the group', 'time': '5 days ago'},
        ];
      case 'g3':
        return [
          {'icon': 'upload', 'text': 'Alice Chen uploaded SGX Enclave Architecture.pdf', 'time': '1 day ago'},
          {'icon': 'pin', 'text': 'Alice Chen pinned SGX Enclave Architecture.pdf', 'time': '1 day ago'},
        ];
      default:
        return const [];
    }
  }
}
