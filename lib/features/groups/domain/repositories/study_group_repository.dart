import '../models/study_group.dart';

abstract interface class StudyGroupRepository {
  Stream<List<StudyGroup>> watchGroups();

  Future<void> createGroup(StudyGroup group);
}
