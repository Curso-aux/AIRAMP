import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import '../database/database_helper.dart';

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
  static const String _settingKey = 'theme_mode';

  @override
  ThemeState build() {
    // Default to dark mode (matches rork's default)
    AppTheme.setDark(true);
    _initPlatformListener();
    return const ThemeState(preference: AppThemeMode.dark, isDark: true);
  }

  void _initPlatformListener() {
    try {
      SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
        if (state.preference == AppThemeMode.auto) {
          final isDark = _computeIsDark(AppThemeMode.auto);
          AppTheme.setDark(isDark);
          state = state.copyWith(isDark: isDark);
        }
      };
    } catch (_) {
      // In testing environments where SchedulerBinding is not yet initialized
    }
  }

  /// Load persisted theme preference from SQLite database.
  Future<void> loadSavedTheme() async {
    try {
      final saved = await DatabaseHelper().getSetting(_settingKey);
      if (saved != null) {
        AppThemeMode mode = AppThemeMode.dark;
        if (saved == 'light') {
          mode = AppThemeMode.light;
        } else if (saved == 'auto') {
          mode = AppThemeMode.auto;
        }
        final isDark = _computeIsDark(mode);
        AppTheme.setDark(isDark);
        state = ThemeState(preference: mode, isDark: isDark);
      }
    } catch (_) {
      // Fallback silently if DB is not yet available
    }
  }

  /// Set the theme mode (light, dark, or auto).
  /// Mirrors rork's ThemeContext.setTheme().
  void setTheme(AppThemeMode mode) {
    final isDark = _computeIsDark(mode);
    AppTheme.setDark(isDark);
    state = state.copyWith(preference: mode, isDark: isDark);

    // Persist in background
    DatabaseHelper().setSetting(_settingKey, mode.name).catchError((_) {});
  }

  /// Toggle between light and dark mode.
  void toggleTheme() {
    final next = state.isDark ? AppThemeMode.light : AppThemeMode.dark;
    setTheme(next);
  }

  bool _computeIsDark(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.auto:
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
