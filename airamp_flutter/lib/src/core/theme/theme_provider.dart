import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme modes matching rork's ThemeMode type.
enum AppThemeMode { light, dark, auto }

/// State holding the user's theme preference and computed dark mode flag.
class ThemeState {
  final AppThemeMode preference;
  final bool isDark;

  const ThemeState({
    this.preference = AppThemeMode.dark,
    this.isDark = true,
  });

  ThemeState copyWith({
    AppThemeMode? preference,
    bool? isDark,
  }) {
    return ThemeState(
      preference: preference ?? this.preference,
      isDark: isDark ?? this.isDark,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // Default to dark mode (matches rork's default)
    return const ThemeState(preference: AppThemeMode.dark, isDark: true);
  }

  /// Set the theme mode (light, dark, or auto).
  /// Mirrors rork's ThemeContext.setTheme().
  void setTheme(AppThemeMode mode) {
    final isDark = _computeIsDark(mode);
    state = state.copyWith(preference: mode, isDark: isDark);
  }

  bool _computeIsDark(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.auto:
        // Use platform brightness to determine dark mode
        final brightness =
            SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  /// Label for the current active mode.
  String get currentModeLabel {
    return state.isDark ? 'Dark Mode' : 'Light Mode';
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});
