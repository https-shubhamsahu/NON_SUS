import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../services/secure_db_service.dart';

class ProfileData {
  final String displayName;
  final String avatarColorStart;
  final String avatarColorEnd;

  const ProfileData({
    required this.displayName,
    required this.avatarColorStart,
    required this.avatarColorEnd,
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
  }) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      avatarColorStart: avatarColorStart ?? this.avatarColorStart,
      avatarColorEnd: avatarColorEnd ?? this.avatarColorEnd,
    );
  }
}

class ProfileNotifier extends Notifier<AsyncValue<ProfileData>> {
  @override
  AsyncValue<ProfileData> build() {
    final authState = ref.watch(authStateProvider);

    // If auth is still loading, try loading onboarding temp profile
    if (authState.isLoading) {
      _loadGuestProfile();
      return const AsyncValue.data(ProfileData(
        displayName: 'Scholar',
        avatarColorStart: 'FF0072FF',
        avatarColorEnd: 'FF00F2FE',
      ));
    }

    final user = authState.value;

    if (user == null) {
      // No authenticated user — load from onboarding cache (bypass auth or guest)
      _loadGuestProfile();
      return const AsyncValue.data(ProfileData(
        displayName: 'Scholar',
        avatarColorStart: 'FF0072FF',
        avatarColorEnd: 'FF00F2FE',
      ));
    }

    // Authenticated user — load their profile from Supabase / local cache
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

  /// Loads the temp onboarding profile saved under 'temp_user' key.
  /// This is set when the user completes the name/avatar selection step
  /// even before they authenticate (or when they bypass auth entirely).
  Future<void> _loadGuestProfile() async {
    try {
      // SecureDbService._profileCache is populated when onboarding saves
      // with userId: 'temp_user'. fetchProfile returns this in-memory cache.
      final cache = await SecureDbService.instance.fetchProfile('temp_user', '');
      final name = cache['displayName'];
      if (name != null && name.isNotEmpty) {
        state = AsyncValue.data(ProfileData(
          displayName: name,
          avatarColorStart: cache['avatarColorStart'] ?? 'FF0072FF',
          avatarColorEnd: cache['avatarColorEnd'] ?? 'FF00F2FE',
        ));
      }
    } catch (_) {
      // Ignore — fallback default stays
    }
  }

  Future<void> _loadProfile(String id, String email) async {
    try {
      final cache = await SecureDbService.instance.fetchProfile(id, email);
      final defaultName = email.isNotEmpty
          ? (email.length > 7 ? email.substring(0, 7) : email)
          : 'Student Guest';
      state = AsyncValue.data(ProfileData(
        displayName: cache['displayName'] ?? defaultName,
        avatarColorStart: cache['avatarColorStart'] ?? 'FF0072FF',
        avatarColorEnd: cache['avatarColorEnd'] ?? 'FF00F2FE',
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
      await SecureDbService.instance.saveProfile(
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
