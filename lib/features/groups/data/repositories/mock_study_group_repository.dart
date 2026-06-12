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
}
