import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/supabase_service.dart';

class ProfileData {
  final String displayName;
  final String avatarColorStart;
  final String avatarColorEnd;
  final String? userType;
  final List<String> goals;
  final List<String> features;

  const ProfileData({
    required this.displayName,
    required this.avatarColorStart,
    required this.avatarColorEnd,
    this.userType,
    this.goals = const [],
    this.features = const [],
  });

  String get avatarId {
    if (avatarColorStart.startsWith('{')) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(avatarColorStart);
        return parsed['avatar_id'] ?? 'avatar_01';
      } catch (_) {
        return 'avatar_01';
      }
    }
    // Legacy hex mapping
    switch (avatarColorStart) {
      case 'FF0072FF':
        return 'avatar_01';
      case 'FFCCCCCC':
        return 'avatar_02';
      case 'FFFF0072':
        return 'avatar_03';
      case 'FFF5A623':
        return 'avatar_04';
      case 'FF800080':
        return 'avatar_05';
      case 'FFADF474':
        return 'avatar_06';
      default:
        return 'avatar_01';
    }
  }

  bool get isCustom {
    if (avatarColorStart.startsWith('{')) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(avatarColorStart);
        return parsed['is_custom'] ?? false;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  ProfileData copyWith({
    String? displayName,
    String? avatarColorStart,
    String? avatarColorEnd,
    String? userType,
    List<String>? goals,
    List<String>? features,
  }) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      avatarColorStart: avatarColorStart ?? this.avatarColorStart,
      avatarColorEnd: avatarColorEnd ?? this.avatarColorEnd,
      userType: userType ?? this.userType,
      goals: goals ?? this.goals,
      features: features ?? this.features,
    );
  }
}

class ProfileNotifier extends Notifier<AsyncValue<ProfileData>> {
  @override
  AsyncValue<ProfileData> build() {
    final authState = ref.watch(authStateProvider);

    // If auth is still loading, return default
    if (authState.isLoading) {
      return const AsyncValue.data(ProfileData(
        displayName: 'Scholar',
        avatarColorStart: 'FF0072FF',
        avatarColorEnd: 'FF00F2FE',
      ));
    }

    final user = authState.value;

    if (user == null) {
      return const AsyncValue.data(ProfileData(
        displayName: 'Scholar',
        avatarColorStart: 'FF0072FF',
        avatarColorEnd: 'FF00F2FE',
      ));
    }

    // Authenticated user — load their profile from Supabase
    _loadProfile(user.id, user.email ?? 'Student Guest');

    // Return a temporary default from email until async load completes
    final defaultName = user.email != null && user.email!.isNotEmpty
        ? (user.email!.length > 7 ? user.email!.substring(0, 7) : user.email!)
        : 'Student Guest';
    return AsyncValue.data(ProfileData(
      displayName: defaultName,
      avatarColorStart: 'FF0072FF',
      avatarColorEnd: 'FF00F2FE',
    ));
  }

  Future<void> _loadProfile(String id, String email) async {
    try {
      final cache = await SupabaseService.instance.fetchProfile(id);
      final defaultName = email.isNotEmpty
          ? (email.length > 7 ? email.substring(0, 7) : email)
          : 'Student Guest';
      
      final goalsList = (cache['survey_goals'] as List?)?.map((e) => e.toString()).toList() ?? const [];
      final featuresList = (cache['survey_features'] as List?)?.map((e) => e.toString()).toList() ?? const [];

      state = AsyncValue.data(ProfileData(
        displayName: cache['display_name'] ?? defaultName,
        avatarColorStart: cache['avatar_color_start'] ?? 'FF0072FF',
        avatarColorEnd: cache['avatar_color_end'] ?? 'FF00F2FE',
        userType: cache['survey_user_type'] as String?,
        goals: goalsList,
        features: featuresList,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String avatarColorStart,
    required String avatarColorEnd,
  }) async {
    final user = ref.read(authStateProvider).value;

    state = const AsyncValue.loading();
    try {
      final userId = user?.id ?? 'temp_user';
      final email = user?.email ?? '';
      await SupabaseService.instance.saveProfile(
        userId: userId,
        email: email,
        displayName: displayName,
        avatarColorStart: avatarColorStart,
        avatarColorEnd: avatarColorEnd,
      );
      state = AsyncValue.data(ProfileData(
        displayName: displayName,
        avatarColorStart: avatarColorStart,
        avatarColorEnd: avatarColorEnd,
      ));
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, AsyncValue<ProfileData>>(
  ProfileNotifier.new,
);
