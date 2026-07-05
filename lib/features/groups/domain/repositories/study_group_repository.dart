import '../models/study_group.dart';

abstract interface class StudyGroupRepository {
  Stream<List<StudyGroup>> watchGroups();

  Future<void> createGroup(StudyGroup group);

  Future<void> ensureCommunityExists(String name, String description, bool isPublic);
  Future<void> joinGroupByName(String name, String userId);
  Future<void> joinGroupByInviteCode(String inviteCode, String userId);
  Future<void> leaveGroup(String groupId, String userId);
  Future<void> deleteGroup(String groupId);
  Future<void> removeMember(String groupId, String memberId);

  Future<List<StudyGroup>> getGroups();
}
