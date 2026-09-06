import 'package:flutter/material.dart';

class AppTheme {
  // Core backgrounds — deep navy gradient
  static const Color background = Color(0xFF0A1420);
  static const Color surface = Color(0xFF11203A);
  static const Color surfaceLight = Color(0xFF192D4A);
  static const Color surfaceElevated = Color(0xFF1E3556);

  // Primary — vibrant teal
  static const Color primary = Color(0xFF00C9A7);
  static const Color primaryDark = Color(0xFF00A88A);
  static const Color primaryLight = Color(0xFF33D4B8);
  static const Color primarySoft = Color(0x1F00C9A7); // approx 0.12 opacity

  // Accent — sky blue
  static const Color accent = Color(0xFF5BA4CF);
  static const Color accentLight = Color(0xFF7DBCE0);
  static const Color accentSoft = Color(0x1F5BA4CF);

  // Text
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B9DC3);
  static const Color textMuted = Color(0xFF5A6B84);
  static const Color textBright = Color(0xFFE8F0FF);

  // Borders & dividers
  static const Color border = Color(0xFF1F3450);
  static const Color borderLight = Color(0xFF2A4368);
  static const Color borderFocus = Color(0xFF00C9A7);

  // Status colors
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorSoft = Color(0x1FFF6B6B);
  static const Color warning = Color(0xFFFFD93D);
  static const Color warningSoft = Color(0x1FFFD93D);
  static const Color success = Color(0xFF00C9A7);
  static const Color successSoft = Color(0x1F00C9A7);
  static const Color locked = Color(0xFF4A5568);
  static const Color lockedSoft = Color(0x264A5568); // approx 0.15

  // Special
  static const Color info = Color(0xFF5BA4CF);
  static const Color infoSoft = Color(0x1F5BA4CF);
  static const Color danger = Color(0xFFFF4757);
  static const Color dangerSoft = Color(0x1FFF4757);

  // Inputs
  static const Color inputBg = Color(0xFF192D4A);
  static const Color inputFocus = Color(0xFF1E3556);

  // Overlays & gradients
  static const Color overlay = Color(0x8C000000); // 0.55 opacity
  static const Color cardGradientStart = Color(0xFF162A42);
  static const Color cardGradientEnd = Color(0xFF0E1E33);

  // Content types
  static const Color pdfColor = Color(0xFFFF6B6B);
  static const Color pptColor = Color(0xFFFF8C42);
  static const Color docColor = Color(0xFF5BA4CF);
  static const Color imageColor = Color(0xFFA78BFA);
  static const Color videoColor = Color(0xFFFF6B6B);
  static const Color youtubeColor = Color(0xFFFF0000);
  static const Color textColor = Color(0xFF00C9A7);

  // Glow / shadow accents
  static const Color glowPrimary = Color(0x4000C9A7); // 0.25 opacity
  static const Color glowAccent = Color(0x335BA4CF); // 0.20 opacity
  static const Color glowError = Color(0x33FF6B6B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: Colors.black, // Dark text on primary button
        onSecondary: Colors.white,
        onSurface: text,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: text, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: text, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: text, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: text, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: text, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text),
        bodySmall: TextStyle(color: textSecondary),
        labelLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size.fromHeight(54),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderFocus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error),
        ),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}
