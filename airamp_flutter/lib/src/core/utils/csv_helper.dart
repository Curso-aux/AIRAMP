/// A lightweight, zero-dependency CSV parser and serializer
/// conforming to RFC-4180 specifications.
class CsvHelper {
  /// Normalizes header string to standard dictionary keys
  static String normalizeHeader(String header) {
    final cleaned = header.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    switch (cleaned) {
      case 'full_name':
      case 'fullname':
      case 'name':
      case 'student_name':
      case 'faculty_name':
      case 'teacher_name':
        return 'full_name';
      case 'email':
      case 'email_address':
      case 'mail':
        return 'email';
      case 'role':
      case 'user_role':
      case 'account_type':
        return 'role';
      case 'grade':
      case 'grade_level':
      case 'year_level':
      case 'year':
        return 'grade';
      case 'section':
      case 'classroom':
      case 'section_name':
      case 'class_section':
        return 'section';
      case 'student_type':
      case 'type':
      case 'classification':
        return 'student_type';
      case 'special_notes':
      case 'notes':
      case 'remarks':
      case 'note':
        return 'special_notes';
      case 'password':
      case 'initial_password':
      case 'pass':
        return 'password';
      default:
        return cleaned;
    }
  }

  /// Parses CSV text into a List of Maps using the header row as keys.
  static List<Map<String, String>> parse(String csvContent) {
    if (csvContent.trim().isEmpty) return [];

    final rawRows = _splitCsvRows(csvContent);
    if (rawRows.isEmpty) return [];

    // Parse header
    final headerTokens = _parseCsvLine(rawRows.first);
    final normalizedHeaders = headerTokens.map(normalizeHeader).toList();

    final results = <Map<String, String>>[];
    for (int i = 1; i < rawRows.length; i++) {
      final line = rawRows[i].trim();
      if (line.isEmpty) continue;

      final values = _parseCsvLine(line);
      final rowMap = <String, String>{};

      for (int h = 0; h < normalizedHeaders.length; h++) {
        final key = normalizedHeaders[h];
        final val = h < values.length ? values[h].trim() : '';
        rowMap[key] = val;
      }

      // Only add if at least email or full_name is non-empty
      if ((rowMap['email']?.isNotEmpty ?? false) || (rowMap['full_name']?.isNotEmpty ?? false)) {
        results.add(rowMap);
      }
    }

    return results;
  }

  /// Splits raw CSV content into logical rows, respecting quoted multiline cells.
  static List<String> _splitCsvRows(String content) {
    final rows = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '"') {
        // Toggle quote state unless escaped quote
        if (inQuotes && i + 1 < content.length && content[i + 1] == '"') {
          buffer.write('""');
          i++; // Skip next quote
          continue;
        }
        inQuotes = !inQuotes;
        buffer.write('"');
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++; // Skip LF after CR
        }
        if (buffer.isNotEmpty) {
          rows.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      rows.add(buffer.toString());
    }

    return rows;
  }

  /// Parses a single CSV line into individual cell tokens.
  static List<String> _parseCsvLine(String line) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        tokens.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    tokens.add(buffer.toString());
    return tokens;
  }

  /// Generates RFC-4180 compliant CSV string from headers and rows
  static String generate({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();

    // Write header
    buffer.writeln(headers.map(_escapeCell).join(','));

    // Write data rows
    for (final row in rows) {
      buffer.writeln(row.map((cell) => _escapeCell(cell?.toString() ?? '')).join(','));
    }

    return buffer.toString();
  }

  /// Escapes a single CSV cell value
  static String _escapeCell(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');

    if (needsQuotes) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  /// Generates a standardized template CSV for bulk student and faculty onboarding.
  static String getStudentTemplateCsv() {
    return [
      'full_name,email,role,grade,section,student_type,special_notes',
      'Juan Dela Cruz,juan.delacruz@school.edu,student,Grade 10,Grade 10 - Emerald,regular,',
      'Maria Santos,maria.santos@school.edu,student,Grade 11,Grade 11 - STEM B,transferee,Transfer from Pasay City Science',
      'Pedro Penduko,pedro.penduko@school.edu,student,Grade 10,Grade 10 - Emerald,irregular,Needs Math remedial assignment',
      'Angela Reyes,angela.reyes@school.edu,student,Grade 10,Grade 10 - Emerald,regular,',
      'Carlos Ramos,carlos.ramos@school.edu,student,Grade 11,Grade 11 - STEM B,sped,Requires visual magnification',
      'Sir Robert Lim,robert.lim@deped.gov.ph,teacher,,,regular,Senior High Mathematics Faculty',
    ].join('\r\n');
  }
}
