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

  /// Extracts an institutional acronym from a campus name
  /// (e.g. "Quezon City Science High School" -> "QCS", "Makati High School" -> "MAK")
  static String deriveCampusAcronym(String campusName) {
    final clean = campusName.trim().toUpperCase();
    if (clean.isEmpty) return 'CMP';

    final stopWords = {
      'OF', 'THE', 'AND', 'IN', 'AT', 'FOR', 'HIGH', 'SCHOOL', 'CAMPUS',
      'BRANCH', 'DEPARTMENT', 'DIVISION', 'INTEGRATED', 'MEMORIAL', 'NATIONAL',
      'SECONDARY', 'ELEMENTARY', 'ACADEMY', 'COLLEGE', 'UNIVERSITY'
    };

    final tokens = clean
        .replaceAll(RegExp(r'[^A-Z0-9\s]'), '')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return 'CMP';

    final meaningful = tokens.where((t) => !stopWords.contains(t)).toList();
    String prefix = '';

    if (meaningful.length >= 3) {
      prefix = meaningful.take(3).map((t) => t[0]).join();
    } else if (meaningful.length == 2) {
      final first = meaningful[0];
      final second = meaningful[1];
      final p1 = first.length >= 2 ? first.substring(0, 2) : first[0];
      final p2 = second[0];
      prefix = '$p1$p2';
    } else if (meaningful.length == 1) {
      final word = meaningful[0];
      if (word.length >= 3) {
        prefix = word.substring(0, 3);
      } else {
        prefix = word.padRight(3, 'X');
      }
    } else {
      prefix = tokens.map((t) => t[0]).take(3).join().padRight(3, 'X');
    }

    return prefix.toUpperCase();
  }

  /// Automatically generates the next unique institutional campus code
  /// (e.g. "Quezon City Science High School" -> "QCS-01")
  static String generateCampusCode({
    required String campusName,
    List<String> existingCodes = const [],
  }) {
    final prefix = deriveCampusAcronym(campusName);

    final normalizedExisting = existingCodes
        .map((c) => c.trim().toUpperCase())
        .where((c) => c.startsWith('$prefix-'))
        .toList();

    int maxSeq = 0;
    for (final code in normalizedExisting) {
      final parts = code.split('-');
      if (parts.length >= 2) {
        final val = int.tryParse(parts.last);
        if (val != null && val > maxSeq) {
          maxSeq = val;
        }
      }
    }

    final seq = (maxSeq + 1).toString().padLeft(2, '0');
    return '$prefix-$seq';
  }
}

