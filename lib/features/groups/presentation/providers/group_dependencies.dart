import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../services/supabase_service.dart';
import '../../data/repositories/mock_study_group_repository.dart';
import '../../data/repositories/supabase_study_group_repository.dart';
import '../../domain/repositories/study_group_repository.dart';

final studyGroupRepositoryProvider = Provider<StudyGroupRepository>((ref) {
  if (SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable) {
    return SupabaseStudyGroupRepository(ref.watch(supabaseClientProvider));
  } else {
    return const MockStudyGroupRepository();
  }
});
