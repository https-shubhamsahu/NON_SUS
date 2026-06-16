import '../models/study_group.dart';

abstract interface class StudyGroupRepository {
  Stream<List<StudyGroup>> watchGroups();

  Future<void> createGroup(StudyGroup group);

  Future<void> ensureCommunityExists(String name, String description, bool isPublic);
  Future<void> joinGroupByName(String name, String userId);
  Future<void> joinGroupByInviteCode(String inviteCode, String userId);
}
