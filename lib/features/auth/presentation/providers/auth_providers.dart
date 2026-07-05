import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_bootstrap.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../services/supabase_service.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../data/repositories/mock_auth_repository.dart';
import '../../data/services/supabase_auth_service.dart';
import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_use_case.dart';
import '../../domain/usecases/sign_up_use_case.dart';
import '../../domain/usecases/sign_out_use_case.dart';

final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService(ref.watch(supabaseClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseBootstrap.isConfigured && SupabaseService.instance.isReachable) {
    return SupabaseAuthRepository(ref.watch(supabaseAuthServiceProvider));
  } else {
    return const MockAuthRepository();
  }
});

final authStateProvider = StreamProvider<AuthenticatedUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthState();
});


final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

