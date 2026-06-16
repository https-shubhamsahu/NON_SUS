import 'dart:async';
import '../../../../services/secure_db_service.dart';
import '../../domain/models/study_group.dart';
import '../../domain/repositories/study_group_repository.dart';

class MockStudyGroupRepository implements StudyGroupRepository {
  const MockStudyGroupRepository();

  @override
  Stream<List<StudyGroup>> watchGroups() {
    return SecureDbService.instance.watchGroups();
  }

  @override
  Future<void> createGroup(StudyGroup group) {
    return SecureDbService.instance.createGroup(group);
  }

  @override
  Future<void> ensureCommunityExists(String name, String description, bool isPublic) async {}

  @override
  Future<void> joinGroupByName(String name, String userId) async {}

  @override
  Future<void> joinGroupByInviteCode(String inviteCode, String userId) async {}
}
