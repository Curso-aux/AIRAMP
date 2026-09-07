import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/theme/theme_provider.dart';

void main() {
  group('AppTheme dynamic colors', () {
    test('AppTheme switches between light and dark colors', () {
      // Test dark mode
      AppTheme.setDark(true);
      expect(AppTheme.isDark, isTrue);
      expect(AppTheme.background, equals(AppTheme.darkBackground));
      expect(AppTheme.surface, equals(AppTheme.darkSurface));
      expect(AppTheme.text, equals(AppTheme.darkText));
      expect(AppTheme.border, equals(AppTheme.darkBorder));

      // Test light mode
      AppTheme.setDark(false);
      expect(AppTheme.isDark, isFalse);
      expect(AppTheme.background, equals(AppTheme.lightBackground));
      expect(AppTheme.surface, equals(AppTheme.lightSurface));
      expect(AppTheme.text, equals(AppTheme.lightText));
      expect(AppTheme.border, equals(AppTheme.lightBorder));
      expect(AppTheme.background, equals(const Color(0xFFF5F7FA)));
      expect(AppTheme.surface, equals(const Color(0xFFFFFFFF)));
      expect(AppTheme.text, equals(const Color(0xFF1A202C)));
    });

    test('ThemeData configurations match brightness', () {
      expect(AppTheme.lightTheme.brightness, equals(Brightness.light));
      expect(AppTheme.darkTheme.brightness, equals(Brightness.dark));

      expect(AppTheme.lightTheme.scaffoldBackgroundColor, equals(AppTheme.lightBackground));
      expect(AppTheme.darkTheme.scaffoldBackgroundColor, equals(AppTheme.darkBackground));
    });
  });

  group('ThemeNotifier state management', () {
    test('initial state defaults to dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(themeProvider);
      expect(state.preference, equals(AppThemeMode.dark));
      expect(state.isDark, isTrue);
    });

    test('setTheme(light) updates state and AppTheme.isDark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(AppThemeMode.light);

      final state = container.read(themeProvider);
      expect(state.preference, equals(AppThemeMode.light));
      expect(state.isDark, isFalse);
      expect(AppTheme.isDark, isFalse);
      expect(AppTheme.background, equals(AppTheme.lightBackground));
      expect(notifier.currentModeLabel, equals('Light Mode'));
    });

    test('setTheme(dark) updates state and AppTheme.isDark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(AppThemeMode.light);
      expect(container.read(themeProvider).isDark, isFalse);

      notifier.setTheme(AppThemeMode.dark);
      expect(container.read(themeProvider).preference, equals(AppThemeMode.dark));
      expect(container.read(themeProvider).isDark, isTrue);
      expect(AppTheme.isDark, isTrue);
      expect(AppTheme.background, equals(AppTheme.darkBackground));
      expect(notifier.currentModeLabel, equals('Dark Mode'));
    });

    test('toggleTheme alternates between light and dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      notifier.setTheme(AppThemeMode.dark);

      notifier.toggleTheme();
      expect(container.read(themeProvider).isDark, isFalse);

      notifier.toggleTheme();
      expect(container.read(themeProvider).isDark, isTrue);
    });

    test('ThemeData includes bottomNavigationBarTheme and outlinedButtonTheme', () {
      expect(AppTheme.lightTheme.bottomNavigationBarTheme.backgroundColor, equals(AppTheme.lightSurface));
      expect(AppTheme.darkTheme.bottomNavigationBarTheme.backgroundColor, equals(AppTheme.darkSurface));

      expect(AppTheme.lightTheme.outlinedButtonTheme.style, isNotNull);
      expect(AppTheme.darkTheme.outlinedButtonTheme.style, isNotNull);
    });
  });
}
