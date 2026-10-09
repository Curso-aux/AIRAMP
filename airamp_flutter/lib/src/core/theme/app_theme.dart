import 'package:flutter/material.dart';
import '../animations/app_transitions.dart';

class AppTheme {
  // Current active mode flag
  static bool _isDark = true;
  static bool get isDark => _isDark;
  static void setDark(bool value) {
    _isDark = value;
  }

  // ── Dark Palette (Ergonomic Slate-Charcoal & Jade) ──────────
  static const Color darkBackground = Color(0xFF0B111A); // Deep, calm slate-charcoal (low blue-light emission)
  static const Color darkSurface = Color(0xFF161F2E);    // Warm, soothing card surface (prevents eye strain)
  static const Color darkSurfaceLight = Color(0xFF222F42); // Elevated layer for chips and button toggles
  static const Color darkSurfaceElevated = Color(0xFF2C3C52); // Modals, sheets, dialogs

  static const Color darkPrimary = Color(0xFF10B981);     // Gentle Emerald / Mint Jade (replaces glaring neon cyan)
  static const Color darkPrimaryDark = Color(0xFF059669); // Grounded deep emerald
  static const Color darkPrimaryLight = Color(0xFF34D399); // Soft pastel mint highlight
  static const Color darkPrimarySoft = Color(0x1F10B981); // 0.12 opacity

  static const Color darkAccent = Color(0xFF38BDF8);      // Soft sky blue (readable, non-vibrating)
  static const Color darkAccentLight = Color(0xFF7DD3FC);
  static const Color darkAccentSoft = Color(0x1F38BDF8);

  static const Color darkText = Color(0xFFF1F5F9);         // Soft Titanium White (stops glare & halation)
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Calm Silver-Slate
  static const Color darkTextMuted = Color(0xFF64748B);     // Muted Slate (clean legibility)
  static const Color darkTextBright = Color(0xFFF8FAFC);    // High-emphasis titles

  static const Color darkBorder = Color(0xFF26354A);      // Subtle, clean border
  static const Color darkBorderLight = Color(0xFF33455E);
  static const Color darkBorderFocus = Color(0xFF10B981);

  static const Color darkError = Color(0xFFEF4444);       // Soft Coral Red (replaces harsh neon pink)
  static const Color darkErrorSoft = Color(0x1FEF4444);
  static const Color darkWarning = Color(0xFFF59E0B);     // Warm Honey Amber (replaces piercing neon yellow)
  static const Color darkWarningSoft = Color(0x1FF59E0B);
  static const Color darkSuccess = Color(0xFF10B981);     // Emerald green
  static const Color darkSuccessSoft = Color(0x1F10B981);
  static const Color darkLocked = Color(0xFF4B5563);
  static const Color darkLockedSoft = Color(0x264B5563);

  static const Color darkInfo = Color(0xFF38BDF8);
  static const Color darkInfoSoft = Color(0x1F38BDF8);
  static const Color darkDanger = Color(0xFFEF4444);
  static const Color darkDangerSoft = Color(0x1FEF4444);

  static const Color darkInputBg = Color(0xFF1B2638);
  static const Color darkInputFocus = Color(0xFF222F42);

  static const Color darkOverlay = Color(0x8C000000);
  static const Color darkCardGradientStart = Color(0xFF192435);
  static const Color darkCardGradientEnd = Color(0xFF131B29);

  static const Color darkPdfColor = Color(0xFFF87171);
  static const Color darkPptColor = Color(0xFFFB923C);
  static const Color darkDocColor = Color(0xFF38BDF8);
  static const Color darkImageColor = Color(0xFFA78BFA);
  static const Color darkVideoColor = Color(0xFFF87171);
  static const Color darkYoutubeColor = Color(0xFFEF4444);
  static const Color darkTextColor = Color(0xFF10B981);

  static const Color darkGlowPrimary = Color(0x3310B981);
  static const Color darkGlowAccent = Color(0x2638BDF8);
  static const Color darkGlowError = Color(0x26EF4444);

  // ── Light Palette (Increased Saturation for High Contrast & Vibrancy) ──
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFF1F5F9);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);

  static const Color lightPrimary = Color(0xFF0D9488);     // Saturated Institutional Teal
  static const Color lightPrimaryDark = Color(0xFF0F766E); // Deep saturated teal
  static const Color lightPrimaryLight = Color(0xFF14B8A6);// Saturated mint highlight
  static const Color lightPrimarySoft = Color(0x1F0D9488); // 0.12 opacity

  static const Color lightAccent = Color(0xFF2563EB);      // Saturated Royal Blue
  static const Color lightAccentLight = Color(0xFF3B82F6);
  static const Color lightAccentSoft = Color(0x1F2563EB);

  static const Color lightText = Color(0xFF0F172A);         // Deep Slate 900 (High contrast)
  static const Color lightTextSecondary = Color(0xFF334155); // Slate 700
  static const Color lightTextMuted = Color(0xFF64748B);     // Slate 500
  static const Color lightTextBright = Color(0xFF0F172A);

  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBorderLight = Color(0xFFCBD5E1);
  static const Color lightBorderFocus = Color(0xFF0D9488);

  static const Color lightError = Color(0xFFDC2626);       // Saturated Ruby Red (High contrast)
  static const Color lightErrorSoft = Color(0x1FDC2626);
  static const Color lightWarning = Color(0xFFD97706);     // Saturated Golden Amber (Replaces muddy yellow)
  static const Color lightWarningSoft = Color(0x1FD97706);
  static const Color lightSuccess = Color(0xFF059669);     // Saturated Emerald Green
  static const Color lightSuccessSoft = Color(0x1F059669);
  static const Color lightLocked = Color(0xFF94A3B8);
  static const Color lightLockedSoft = Color(0x1F94A3B8);

  static const Color lightInfo = Color(0xFF0284C7);        // Saturated Cerulean / Sky
  static const Color lightInfoSoft = Color(0x1F0284C7);
  static const Color lightDanger = Color(0xFFDC2626);
  static const Color lightDangerSoft = Color(0x1FDC2626);

  static const Color lightInputBg = Color(0xFFFFFFFF);
  static const Color lightInputFocus = Color(0xFFF8FAFC);

  static const Color lightOverlay = Color(0x73000000);
  static const Color lightCardGradientStart = Color(0xFFFFFFFF);
  static const Color lightCardGradientEnd = Color(0xFFF1F5F9);

  static const Color lightPdfColor = Color(0xFFDC2626);    // Saturated Crimson
  static const Color lightPptColor = Color(0xFFEA580C);    // Saturated Flame Orange
  static const Color lightDocColor = Color(0xFF2563EB);    // Saturated Royal Blue
  static const Color lightImageColor = Color(0xFF7C3AED);  // Saturated Royal Violet
  static const Color lightVideoColor = Color(0xFFE11D48);  // Saturated Ruby
  static const Color lightYoutubeColor = Color(0xFFFF0000);
  static const Color lightTextColor = Color(0xFF0D9488);

  static const Color lightGlowPrimary = Color(0x330D9488);
  static const Color lightGlowAccent = Color(0x262563EB);
  static const Color lightGlowError = Color(0x26DC2626);

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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        modalBackgroundColor: darkSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: Colors.black,
          animationDuration: const Duration(milliseconds: 200),
          splashFactory: InkSparkle.splashFactory,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 54),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkText,
          animationDuration: const Duration(milliseconds: 200),
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: const Duration(milliseconds: 180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          animationDuration: const Duration(milliseconds: 180),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SmoothPageTransitionsBuilder(),
          TargetPlatform.iOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.windows: SmoothPageTransitionsBuilder(),
          TargetPlatform.macOS: SmoothPageTransitionsBuilder(),
          TargetPlatform.linux: SmoothPageTransitionsBuilder(),
          TargetPlatform.fuchsia: SmoothPageTransitionsBuilder(),
        },
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        modalBackgroundColor: lightSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          animationDuration: const Duration(milliseconds: 200),
          splashFactory: InkSparkle.splashFactory,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(0, 54),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightText,
          animationDuration: const Duration(milliseconds: 200),
          side: const BorderSide(color: lightBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: const Duration(milliseconds: 180),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          animationDuration: const Duration(milliseconds: 180),
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
    );
  }
}
