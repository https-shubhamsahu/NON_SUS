import 'supabase_service.dart';

class FocusService {
  static final FocusService instance = FocusService._internal();
  FocusService._internal();

  final Map<String, int> _mockFocusLogs = {}; // dateString -> minutes

  bool _isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  Future<Map<DateTime, int>> fetchFocusLogs(String userId) async {
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      return await SupabaseService.instance.fetchFocusLogs(userId);
    }
    return {};
  }

  Future<void> incrementFocusMinutes(String userId, int minutes) async {
    if (SupabaseService.instance.isReachable && _isValidUuid(userId)) {
      await SupabaseService.instance.incrementFocusMinutes(userId, minutes);
      return;
    }
    final todayStr = DateTime.now().toLocal().toIso8601String().substring(0, 10);
    final current = _mockFocusLogs[todayStr] ?? 0;
    _mockFocusLogs[todayStr] = current + minutes;
  }
}
