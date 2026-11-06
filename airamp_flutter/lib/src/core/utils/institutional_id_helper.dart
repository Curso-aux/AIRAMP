/// Scalable Institutional Identifier Utility
/// Supports the modern multi-campus format:
/// - Super Admin: SA-000-XXXX
/// - Campus Admin: A-100-XXXX
/// - Teacher:      T-100-XXXX
/// - Student:      S-100-XXXX
///
/// Also provides backwards-compatibility detection for legacy IDs (001-XXXX, 002-XXXX, ADM-XX).
class InstitutionalIdHelper {
  static final RegExp idRegex = RegExp(
    r'^(SA|A|T|S)-(000|\d{3})-\d{4,5}$',
    caseSensitive: false,
  );

  /// Normalizes and cleans an input ID (uppercases and trims)
  static String normalize(String input) {
    String clean = input.trim().toUpperCase();
    // Auto-hyphenate if entered without dashes (e.g. S1000001 -> S-100-0001)
    final match = RegExp(r'^(SA|A|T|S)(\d{3})(\d{4,5})$').firstMatch(clean);
    if (match != null) {
      return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
    }
    return clean;
  }

  /// Detects user role from their Institutional ID prefix
  static String? detectRole(String accountId) {
    final clean = normalize(accountId);
    if (clean.startsWith('SA-') || clean.startsWith('SA_')) {
      return 'super_admin';
    }
    if (clean.startsWith('A-') || clean.startsWith('ADM-') || clean.startsWith('ADMIN_')) {
      return 'admin';
    }
    if (clean.startsWith('T-') || clean.startsWith('002-') || clean.startsWith('TCH_')) {
      return 'teacher';
    }
    if (clean.startsWith('S-') || clean.startsWith('001-') || clean.startsWith('STD_')) {
      return 'student';
    }
    return null;
  }

  /// Checks if an ID string matches standard institutional format
  static bool isValid(String accountId) {
    final clean = normalize(accountId);
    if (idRegex.hasMatch(clean)) return true;
    // Legacy support
    if (RegExp(r'^(001|002)-\d{4}$').hasMatch(clean)) return true;
    if (RegExp(r'^ADM-\d{2}$').hasMatch(clean)) return true;
    return false;
  }
}

