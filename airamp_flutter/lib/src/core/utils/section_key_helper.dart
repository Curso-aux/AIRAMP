import 'dart:math';

/// Utility class to automatically generate clean, standardized, DepEd-aligned
/// section enrollment keys for students (e.g. SEC-EMR10, SEC-STEM11, SEC-SAPH10).
class SectionKeyHelper {
  /// Known friendly abbreviations for common section monikers
  static const Map<String, String> _knownAbbreviations = {
    'EMERALD': 'EMR',
    'SAPPHIRE': 'SAPH',
    'DIAMOND': 'DIAM',
    'RUBY': 'RUBY',
    'GOLD': 'GOLD',
    'SILVER': 'SLVR',
    'PEARL': 'PEARL',
    'AMETHYST': 'AMTH',
    'GARNET': 'GARN',
    'JADE': 'JADE',
    'TOPAZ': 'TOPAZ',
    'OPAL': 'OPAL',
    'EINSTEIN': 'EINS',
    'NEWTON': 'NEWT',
    'GALILEO': 'GALI',
    'CURIE': 'CURIE',
    'EDISON': 'EDIS',
    'TESLA': 'TESLA',
    'RIZAL': 'RIZAL',
    'BONIFACIO': 'BONI',
    'MABINI': 'MAB',
    'LUNA': 'LUNA',
    'SILANG': 'SILANG',
  };

  /// Generates a standardized, clean section enrollment key.
  /// Example outputs:
  /// - "Grade 10 - Emerald" -> "SEC-EMR10"
  /// - "Grade 11 - STEM B" -> "SEC-STEM11"
  /// - "Grade 12 - Gold" -> "SEC-GOLD12"
  /// - "Grade 10 - Sapphire" -> "SEC-SAPH10"
  /// - "Grade 7 - Rizal" -> "SEC-RIZAL7"
  static String generateKey({
    required String sectionName,
    String? gradeLevel,
    String? customSuffix,
  }) {
    // 1. Extract grade digits (e.g., 'Grade 10' -> '10', 'Grade 7' -> '7')
    String gradeNum = '';
    final gradeText = (gradeLevel != null && gradeLevel.isNotEmpty) ? gradeLevel : sectionName;
    final gradeMatch = RegExp(r'\b(?:Grade\s*|G)(\d{1,2})\b', caseSensitive: false).firstMatch(gradeText);
    if (gradeMatch != null) {
      gradeNum = gradeMatch.group(1)!;
    } else {
      final numMatch = RegExp(r'\b(7|8|9|10|11|12)\b').firstMatch(sectionName);
      if (numMatch != null) {
        gradeNum = numMatch.group(1)!;
      }
    }
    if (gradeNum.isEmpty) {
      gradeNum = '10';
    }

    // 2. Extract and sanitize section identifier tokens
    String clean = sectionName
        .replaceAll(RegExp(r'\b(?:Grade|Section|Class|Room)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(7|8|9|10|11|12)\b'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), ' ')
        .trim();

    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    String baseIdentifier = '';

    if (parts.isNotEmpty) {
      final first = parts.first.toUpperCase();

      if (_knownAbbreviations.containsKey(first)) {
        baseIdentifier = _knownAbbreviations[first]!;
      } else if (first.startsWith('STEM')) {
        final extra = parts.length > 1 ? parts[1].toUpperCase() : '';
        baseIdentifier = extra.isNotEmpty ? 'STEM$extra' : 'STEM';
      } else if (first.startsWith('ABM')) {
        final extra = parts.length > 1 ? parts[1].toUpperCase() : '';
        baseIdentifier = extra.isNotEmpty ? 'ABM$extra' : 'ABM';
      } else if (first.startsWith('HUMSS')) {
        baseIdentifier = 'HUMSS';
      } else if (first.startsWith('TVL') || first.startsWith('ICT')) {
        final extra = parts.length > 1 ? parts[1].toUpperCase() : '';
        baseIdentifier = extra.isNotEmpty ? 'ICT$extra' : 'ICT';
      } else if (first.startsWith('GAS')) {
        baseIdentifier = 'GAS';
      } else {
        baseIdentifier = first.length <= 5 ? first : first.substring(0, 4);
      }
    } else {
      baseIdentifier = 'SEC';
    }

    String key = 'SEC-$baseIdentifier$gradeNum'.toUpperCase();

    if (customSuffix != null && customSuffix.isNotEmpty) {
      key = '$key-$customSuffix';
    }

    return key;
  }

  /// Generates a randomized variation of the key with a short 3-character suffix.
  static String generateRandomVariation({
    required String sectionName,
    String? gradeLevel,
  }) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final suffix = List.generate(3, (_) => chars[rand.nextInt(chars.length)]).join();
    return generateKey(
      sectionName: sectionName,
      gradeLevel: gradeLevel,
      customSuffix: suffix,
    );
  }

  /// Resolves the grade level label (e.g. 'Grade 7', 'Grade 10', 'Grade 11')
  /// from a section name or grade hint string.
  static String extractGradeFromSection(String sectionName, [String? gradeHint]) {
    if (gradeHint != null && gradeHint.trim().isNotEmpty && gradeHint.startsWith('Grade')) {
      return gradeHint.trim();
    }
    final gradeMatch = RegExp(r'\b(?:Grade\s*|G)(\d{1,2})\b', caseSensitive: false).firstMatch(sectionName);
    if (gradeMatch != null) {
      return 'Grade ${gradeMatch.group(1)}';
    }
    final numMatch = RegExp(r'\b(7|8|9|10|11|12)\b').firstMatch(sectionName);
    if (numMatch != null) {
      return 'Grade ${numMatch.group(1)}';
    }
    return 'Grade 10';
  }
}
