import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import '../database/database_helper.dart';

/// Theme modes for the application (light and dark).
enum AppThemeMode { light, dark }

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
    // Default to dark mode
    AppTheme.setDark(true);
    return const ThemeState(preference: AppThemeMode.dark, isDark: true);
  }

  /// Load persisted theme preference from SQLite database.
  Future<void> loadSavedTheme() async {
    try {
      final saved = await DatabaseHelper().getSetting(_settingKey);
      if (saved != null) {
        final mode = saved == 'light' ? AppThemeMode.light : AppThemeMode.dark;
        final isDark = mode == AppThemeMode.dark;
        AppTheme.setDark(isDark);
        state = ThemeState(preference: mode, isDark: isDark);
      }
    } catch (_) {
      // Fallback silently if DB is not yet available
    }
  }

  /// Set the theme mode (light or dark).
  void setTheme(AppThemeMode mode) {
    final isDark = mode == AppThemeMode.dark;
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

  /// Label for the current active mode.
  String get currentModeLabel {
    return state.isDark ? 'Dark Mode' : 'Light Mode';
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});
