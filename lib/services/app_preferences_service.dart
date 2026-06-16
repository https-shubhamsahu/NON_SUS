import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  static final AppPreferencesService instance = AppPreferencesService._internal();
  AppPreferencesService._internal();

  bool _onboardingCompleted = false;
  bool _guestMode = false;
  String _userType = 'student';

  static const _kOnboardingKey = 'nosus_onboarding_done';
  static const _kGuestModeKey = 'nosus_guest_mode';
  static const _kUserTypeKey = 'nosus_user_type';

  Future<void> loadPersistedState() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingCompleted = prefs.getBool(_kOnboardingKey) ?? false;
    _guestMode = prefs.getBool(_kGuestModeKey) ?? false;
    _userType = prefs.getString(_kUserTypeKey) ?? 'student';
  }

  bool isOnboardingCompleted() => _onboardingCompleted;

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
  }

  bool isGuestMode() => _guestMode;

  Future<void> setGuestMode(bool value) async {
    _guestMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestModeKey, value);
  }

  String get userType => _userType;

  Future<void> setUserType(String value) async {
    _userType = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserTypeKey, value);
  }

  Future<void> resetAppState() async {
    _onboardingCompleted = false;
    _guestMode = false;
    _userType = 'student';
    final prefs = await SharedPreferences.getInstance();
    // Only delete specific keys to avoid clearing secure_storage keys or auth states 
    // if they happened to be stored in SharedPreferences (which they shouldn't be anymore).
    await prefs.remove(_kOnboardingKey);
    await prefs.remove(_kGuestModeKey);
    await prefs.remove(_kUserTypeKey);
  }
}
