import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scheduled Quiz Availability & Unlock Logic Tests', () {
    bool isDatePassed(String isoString, DateTime referenceNow) {
      try {
        final sanitized = isoString.contains(' ') && !isoString.contains('T')
            ? isoString.replaceAll(' ', 'T')
            : isoString;
        final dt = DateTime.parse(sanitized).toLocal();
        if (sanitized.length <= 10 && !sanitized.contains('T')) {
          final endOfDay = DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
          return !endOfDay.isAfter(referenceNow);
        }
        return !dt.isAfter(referenceNow);
      } catch (_) {
        return true;
      }
    }

    test('1. Quiz unlocks when current time reaches or passes schedule start time', () {
      final scheduleStart = '2026-10-20T16:23:00.000';

      // Before start time (e.g., 4:22 PM) -> locked
      final beforeTime = DateTime(2026, 10, 20, 16, 22, 0);
      expect(isDatePassed(scheduleStart, beforeTime), isFalse);

      // Exact start time (4:23:00 PM) -> unlocked
      final exactTime = DateTime(2026, 10, 20, 16, 23, 0);
      expect(isDatePassed(scheduleStart, exactTime), isTrue);

      // After start time (4:24:37 PM, as reported by user) -> unlocked
      final userCurrentTime = DateTime(2026, 10, 20, 16, 24, 37);
      expect(isDatePassed(scheduleStart, userCurrentTime), isTrue);
    });

    test('2. Quiz handles SQL-formatted space separated dates', () {
      final sqlDate = '2026-10-20 16:23:00';

      final userCurrentTime = DateTime(2026, 10, 20, 16, 24, 37);
      expect(isDatePassed(sqlDate, userCurrentTime), isTrue);

      final beforeTime = DateTime(2026, 10, 20, 16, 20, 0);
      expect(isDatePassed(sqlDate, beforeTime), isFalse);
    });

    test('3. Countdown calculation returns Duration.zero when start time has passed', () {
      final scheduleDate = DateTime(2026, 10, 20, 16, 23, 0);
      final now = DateTime(2026, 10, 20, 16, 24, 37);

      final diff = scheduleDate.difference(now);
      final remaining = diff.isNegative ? Duration.zero : diff;

      expect(remaining, Duration.zero);
      expect(scheduleDate.isAfter(now), isFalse);
    });

    test('4. Countdown calculation returns accurate duration when start time is in future', () {
      final scheduleDate = DateTime(2026, 10, 20, 16, 23, 0);
      final now = DateTime(2026, 10, 20, 16, 20, 30);

      final diff = scheduleDate.difference(now);
      final remaining = diff.isNegative ? Duration.zero : diff;

      expect(remaining.inMinutes, 2);
      expect(remaining.inSeconds % 60, 30);
    });
  });
}
