import 'package:flutter/material.dart';

class AppTheme {
  // Current active mode flag
  static bool _isDark = true;
  static bool get isDark => _isDark;
  static void setDark(bool value) {
    _isDark = value;
  }

  // ── Dark Palette ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0A1420);
  static const Color darkSurface = Color(0xFF11203A);
  static const Color darkSurfaceLight = Color(0xFF192D4A);
  static const Color darkSurfaceElevated = Color(0xFF1E3556);

  static const Color darkPrimary = Color(0xFF00C9A7);
  static const Color darkPrimaryDark = Color(0xFF00A88A);
  static const Color darkPrimaryLight = Color(0xFF33D4B8);
  static const Color darkPrimarySoft = Color(0x1F00C9A7); // 0.12 opacity

  static const Color darkAccent = Color(0xFF5BA4CF);
  static const Color darkAccentLight = Color(0xFF7DBCE0);
  static const Color darkAccentSoft = Color(0x1F5BA4CF);

  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF8B9DC3);
  static const Color darkTextMuted = Color(0xFF5A6B84);
  static const Color darkTextBright = Color(0xFFE8F0FF);

  static const Color darkBorder = Color(0xFF1F3450);
  static const Color darkBorderLight = Color(0xFF2A4368);
  static const Color darkBorderFocus = Color(0xFF00C9A7);

  static const Color darkError = Color(0xFFFF6B6B);
  static const Color darkErrorSoft = Color(0x1FFF6B6B);
  static const Color darkWarning = Color(0xFFFFD93D);
  static const Color darkWarningSoft = Color(0x1FFFD93D);
  static const Color darkSuccess = Color(0xFF00C9A7);
  static const Color darkSuccessSoft = Color(0x1F00C9A7);
  static const Color darkLocked = Color(0xFF4A5568);
  static const Color darkLockedSoft = Color(0x264A5568);

  static const Color darkInfo = Color(0xFF5BA4CF);
  static const Color darkInfoSoft = Color(0x1F5BA4CF);
  static const Color darkDanger = Color(0xFFFF4757);
  static const Color darkDangerSoft = Color(0x1FFF4757);

  static const Color darkInputBg = Color(0xFF192D4A);
  static const Color darkInputFocus = Color(0xFF1E3556);

  static const Color darkOverlay = Color(0x8C000000);
  static const Color darkCardGradientStart = Color(0xFF162A42);
  static const Color darkCardGradientEnd = Color(0xFF0E1E33);

  static const Color darkPdfColor = Color(0xFFFF6B6B);
  static const Color darkPptColor = Color(0xFFFF8C42);
  static const Color darkDocColor = Color(0xFF5BA4CF);
  static const Color darkImageColor = Color(0xFFA78BFA);
  static const Color darkVideoColor = Color(0xFFFF6B6B);
  static const Color darkYoutubeColor = Color(0xFFFF0000);
  static const Color darkTextColor = Color(0xFF00C9A7);

  static const Color darkGlowPrimary = Color(0x4000C9A7);
  static const Color darkGlowAccent = Color(0x335BA4CF);
  static const Color darkGlowError = Color(0x33FF6B6B);

  // ── Light Palette ─────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF0F4F8);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color lightPrimary = Color(0xFF00A88A);
  static const Color lightPrimaryDark = Color(0xFF008B72);
  static const Color lightPrimaryLight = Color(0xFF33D4B8);
  static const Color lightPrimarySoft = Color(0x1A00A88A); // 0.10 opacity

  static const Color lightAccent = Color(0xFF4A90D9);
  static const Color lightAccentLight = Color(0xFF7DBCE0);
  static const Color lightAccentSoft = Color(0x1A4A90D9);

  static const Color lightText = Color(0xFF1A202C);
  static const Color lightTextSecondary = Color(0xFF4A5568);
  static const Color lightTextMuted = Color(0xFF718096);
  static const Color lightTextBright = Color(0xFF1A202C);

  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderLight = Color(0xFFCBD5E0);
  static const Color lightBorderFocus = Color(0xFF00A88A);

  static const Color lightError = Color(0xFFE53E3E);
  static const Color lightErrorSoft = Color(0x14E53E3E);
  static const Color lightWarning = Color(0xFFD69E2E);
  static const Color lightWarningSoft = Color(0x1AD69E2E);
  static const Color lightSuccess = Color(0xFF00A88A);
  static const Color lightSuccessSoft = Color(0x1A00A88A);
  static const Color lightLocked = Color(0xFFA0AEC0);
  static const Color lightLockedSoft = Color(0x1FA0AEC0);

  static const Color lightInfo = Color(0xFF4A90D9);
  static const Color lightInfoSoft = Color(0x1A4A90D9);
  static const Color lightDanger = Color(0xFFE53E3E);
  static const Color lightDangerSoft = Color(0x14E53E3E);

  static const Color lightInputBg = Color(0xFFFFFFFF);
  static const Color lightInputFocus = Color(0xFFF0F4F8);

  static const Color lightOverlay = Color(0x73000000);
  static const Color lightCardGradientStart = Color(0xFFFFFFFF);
  static const Color lightCardGradientEnd = Color(0xFFF0F4F8);

  static const Color lightPdfColor = Color(0xFFE53E3E);
  static const Color lightPptColor = Color(0xFFDD6B20);
  static const Color lightDocColor = Color(0xFF4A90D9);
  static const Color lightImageColor = Color(0xFF805AD5);
  static const Color lightVideoColor = Color(0xFFE53E3E);
  static const Color lightYoutubeColor = Color(0xFFFF0000);
  static const Color lightTextColor = Color(0xFF00A88A);

  static const Color lightGlowPrimary = Color(0x2600A88A);
  static const Color lightGlowAccent = Color(0x1F4A90D9);
  static const Color lightGlowError = Color(0x1FE53E3E);

  // ── Dynamic Color Getters ─────────────────────────────────
  static Color get background => _isDark ? darkBackground : lightBackground;
  static Color get surface => _isDark ? darkSurface : lightSurface;
  static Color get surfaceLight => _isDark ? darkSurfaceLight : lightSurfaceLight;
  static Color get surfaceElevated => _isDark ? darkSurfaceElevated : lightSurfaceElevated;

  static Color get primary => _isDark ? darkPrimary : lightPrimary;
  static Color get primaryDark => _isDark ? darkPrimaryDark : lightPrimaryDark;
  static Color get primaryLight => _isDark ? darkPrimaryLight : lightPrimaryLight;
  static Color get primarySoft => _isDark ? darkPrimarySoft : lightPrimarySoft;

  static Color get accent => _isDark ? darkAccent : lightAccent;
  static Color get accentLight => _isDark ? darkAccentLight : lightAccentLight;
  static Color get accentSoft => _isDark ? darkAccentSoft : lightAccentSoft;

  static Color get text => _isDark ? darkText : lightText;
  static Color get textSecondary => _isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted => _isDark ? darkTextMuted : lightTextMuted;
  static Color get textBright => _isDark ? darkTextBright : lightTextBright;

  static Color get border => _isDark ? darkBorder : lightBorder;
  static Color get borderLight => _isDark ? darkBorderLight : lightBorderLight;
  static Color get borderFocus => _isDark ? darkBorderFocus : lightBorderFocus;

  static Color get error => _isDark ? darkError : lightError;
  static Color get errorSoft => _isDark ? darkErrorSoft : lightErrorSoft;
  static Color get warning => _isDark ? darkWarning : lightWarning;
  static Color get warningSoft => _isDark ? darkWarningSoft : lightWarningSoft;
  static Color get success => _isDark ? darkSuccess : lightSuccess;
  static Color get successSoft => _isDark ? darkSuccessSoft : lightSuccessSoft;
  static Color get locked => _isDark ? darkLocked : lightLocked;
  static Color get lockedSoft => _isDark ? darkLockedSoft : lightLockedSoft;

  static Color get info => _isDark ? darkInfo : lightInfo;
  static Color get infoSoft => _isDark ? darkInfoSoft : lightInfoSoft;
  static Color get danger => _isDark ? darkDanger : lightDanger;
  static Color get dangerSoft => _isDark ? darkDangerSoft : lightDangerSoft;

  static Color get inputBg => _isDark ? darkInputBg : lightInputBg;
  static Color get inputFocus => _isDark ? darkInputFocus : lightInputFocus;

  static Color get overlay => _isDark ? darkOverlay : lightOverlay;
  static Color get cardGradientStart => _isDark ? darkCardGradientStart : lightCardGradientStart;
  static Color get cardGradientEnd => _isDark ? darkCardGradientEnd : lightCardGradientEnd;

  static Color get pdfColor => _isDark ? darkPdfColor : lightPdfColor;
  static Color get pptColor => _isDark ? darkPptColor : lightPptColor;
  static Color get docColor => _isDark ? darkDocColor : lightDocColor;
  static Color get imageColor => _isDark ? darkImageColor : lightImageColor;
  static Color get videoColor => _isDark ? darkVideoColor : lightVideoColor;
  static Color get youtubeColor => _isDark ? darkYoutubeColor : lightYoutubeColor;
  static Color get textColor => _isDark ? darkTextColor : lightTextColor;

  static Color get glowPrimary => _isDark ? darkGlowPrimary : lightGlowPrimary;
  static Color get glowAccent => _isDark ? darkGlowAccent : lightGlowAccent;
  static Color get glowError => _isDark ? darkGlowError : lightGlowError;

  // ── Dark Theme ThemeData ──────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      primaryColor: darkPrimary,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkAccent,
        surface: darkSurface,
        error: darkError,
        onPrimary: Colors.black,
        onSecondary: Colors.white,
        onSurface: darkText,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: darkText),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 54),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorderFocus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkError),
        ),
        hintStyle: const TextStyle(color: darkTextMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          side: const BorderSide(color: darkBorder),
        ),
      ),
    );
  }

  // ── Light Theme ThemeData ─────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      primaryColor: lightPrimary,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightAccent,
        surface: lightSurface,
        error: lightError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightText,
        onError: Colors.white,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: lightText),
        bodyMedium: TextStyle(color: lightText),
        bodySmall: TextStyle(color: lightTextSecondary),
        labelLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: lightTextSecondary),
        labelSmall: TextStyle(color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 54),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorderFocus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightError),
        ),
        hintStyle: const TextStyle(color: lightTextMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder, thickness: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightTextMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          side: const BorderSide(color: lightBorder),
        ),
      ),
    );
  }
}
