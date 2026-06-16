import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global theme mode provider — replaces the `setState`-based `_themeMode` in MyApp.
///
/// Moving theme state here means toggling dark/light mode only rebuilds
/// `MaterialApp`'s `themeMode` property — not the entire `WorkspaceHome` tree.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
  
  void setMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
