import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme mode provider — replaces the `setState`-based `_themeMode` in MyApp.
///
/// Moving theme state here means toggling dark/light mode only rebuilds
/// `MaterialApp`'s `themeMode` property — not the entire `WorkspaceHome` tree.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'nosus_theme_mode';

  @override
  ThemeMode build() {
    _loadState();
    return ThemeMode.dark;
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(_key);
      if (val != null) {
        state = val == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
    } catch (_) {}
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, newMode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
  
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
