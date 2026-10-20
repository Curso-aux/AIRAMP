/// Helper utility for handling Philippine Standard Time (PST/PHT: UTC+8)
/// across AIRAMP. Guarantees accurate date/time comparisons and countdowns
/// even on devices or Android emulators running in GMT / UTC or other timezones.
class PhilippineTimeHelper {
  PhilippineTimeHelper._();

  /// Philippine Standard Time offset: UTC+8 (no Daylight Saving Time).
  static const Duration phtOffset = Duration(hours: 8);

  /// Returns current wall-clock [DateTime] in Philippine Standard Time (UTC+8).
  ///
  /// Works reliably on any device regardless of device timezone settings
  /// (e.g. Android emulator running with default GMT clock).
  static DateTime now() {
    final utc = DateTime.now().toUtc();
    final pht = utc.add(phtOffset);
    return DateTime(
      pht.year,
      pht.month,
      pht.day,
      pht.hour,
      pht.minute,
      pht.second,
      pht.millisecond,
    );
  }

  /// Parses an ISO string or SQLite timestamp into Philippine wall-clock [DateTime].
  ///
  /// - If the string has an explicit timezone (`Z`, `+08:00`, etc.), it converts to UTC
  ///   and then projects into Philippine Time (UTC+8).
  /// - If the string is a naive local timestamp (e.g. `2026-10-20T16:52:00`), it is treated
  ///   as wall-clock Philippine Time as selected by the school/instructor.
  static DateTime? parseToPht(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final sanitized = raw.trim().replaceAll(' ', 'T');

      final hasZ = sanitized.endsWith('Z');
      final hasTimezoneOffset = sanitized.contains('+') ||
          (sanitized.length > 10 && sanitized.indexOf('-', 10) != -1);

      if (hasZ || hasTimezoneOffset) {
        final utc = DateTime.parse(sanitized).toUtc();
        final pht = utc.add(phtOffset);
        return DateTime(
          pht.year,
          pht.month,
          pht.day,
          pht.hour,
          pht.minute,
          pht.second,
          pht.millisecond,
        );
      } else {
        final parsed = DateTime.parse(sanitized);
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
        );
      }
    } catch (_) {
      return null;
    }
  }

  /// Checks if a scheduled start time or deadline has arrived in Philippine Time.
  ///
  /// - For datetime strings (with `T` or time component): returns `true` if `now() >= dt`.
  /// - For date-only strings (e.g. `2026-10-20`): returns `true` only after 23:59:59 PHT on that date.
  static bool isDatePassed(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) return true;
    final dt = parseToPht(isoString);
    if (dt == null) return true;

    final nowPht = now();
    final trimmed = isoString.trim();
    if (trimmed.length <= 10 && !trimmed.contains('T') && !trimmed.contains(' ')) {
      final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
      return !endOfDay.isAfter(nowPht);
    }
    return !dt.isAfter(nowPht);
  }

  /// Returns remaining duration until [isoString] arrives in Philippine Time.
  /// Returns [Duration.zero] if the time has already passed.
  static Duration timeUntil(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) return Duration.zero;
    final dt = parseToPht(isoString);
    if (dt == null) return Duration.zero;
    final diff = dt.difference(now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Formats a remaining [Duration] into a clean user-facing string (e.g. `2 min 15s`).
  static String formatRemaining(Duration duration) {
    if (duration <= Duration.zero) return '0s';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '$minutes min ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Formats an ISO string into Philippine Time format: `Oct 20 at 4:52 PM`.
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) return '';
    final dt = parseToPht(isoString);
    if (dt == null) return isoString;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}';
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dateStr at $hour:$min $ampm';
  }

  /// Formats an ISO date into full format with year: `Oct 20, 2026 at 4:52 PM`
  /// or date-only if no time component exists.
  static String formatDate(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) return 'Recent';
    final dt = parseToPht(isoString);
    if (dt == null) return isoString;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    final trimmed = isoString.trim();
    if (trimmed.contains('T') || trimmed.contains(' ') || trimmed.length > 10) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '$dateStr at $hour:$min $ampm';
    }
    return dateStr;
  }
}
