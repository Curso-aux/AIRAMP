import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/utils/philippine_time_helper.dart';

void main() {
  group('PhilippineTimeHelper Tests', () {
    test('1. now() returns UTC+8 time', () {
      final utc = DateTime.now().toUtc();
      final pht = PhilippineTimeHelper.now();

      final expectedPhtHour = (utc.hour + 8) % 24;
      expect(pht.hour, expectedPhtHour);
    });

    test('2. parseToPht handles naive local ISO strings as Philippine wall-clock time', () {
      final pht = PhilippineTimeHelper.parseToPht('2026-10-20T16:52:00.000');
      expect(pht, isNotNull);
      expect(pht!.year, 2026);
      expect(pht.month, 10);
      expect(pht.day, 20);
      expect(pht.hour, 16);
      expect(pht.minute, 52);
    });

    test('3. parseToPht handles space-separated SQL timestamps', () {
      final pht = PhilippineTimeHelper.parseToPht('2026-10-20 16:52:00');
      expect(pht, isNotNull);
      expect(pht!.hour, 16);
      expect(pht.minute, 52);
    });

    test('4. parseToPht handles UTC string ending in Z by converting to UTC+8', () {
      // 08:52:00 UTC should be 16:52:00 in PHT (UTC+8)
      final pht = PhilippineTimeHelper.parseToPht('2026-10-20T08:52:00Z');
      expect(pht, isNotNull);
      expect(pht!.hour, 16);
      expect(pht.minute, 52);
    });

    test('5. isDatePassed returns true when scheduled time has passed in Philippine Time', () {
      // 10 minutes in the past
      final pastTime = PhilippineTimeHelper.now().subtract(const Duration(minutes: 10));
      final pastIso = pastTime.toIso8601String();

      expect(PhilippineTimeHelper.isDatePassed(pastIso), isTrue);
    });

    test('6. isDatePassed returns false when scheduled time is in the future in Philippine Time', () {
      // 10 minutes in the future
      final futureTime = PhilippineTimeHelper.now().add(const Duration(minutes: 10));
      final futureIso = futureTime.toIso8601String();

      expect(PhilippineTimeHelper.isDatePassed(futureIso), isFalse);
    });

    test('7. timeUntil returns Duration.zero when time has already passed', () {
      final pastTime = PhilippineTimeHelper.now().subtract(const Duration(minutes: 5));
      expect(PhilippineTimeHelper.timeUntil(pastTime.toIso8601String()), Duration.zero);
    });

    test('8. timeUntil returns correct remaining duration for future time', () {
      final futureTime = PhilippineTimeHelper.now().add(const Duration(minutes: 5, seconds: 30));
      final remaining = PhilippineTimeHelper.timeUntil(futureTime.toIso8601String());

      expect(remaining.inMinutes, inInclusiveRange(4, 5));
      expect(remaining.inSeconds, inInclusiveRange(320, 335));
    });

    test('9. formatRemaining returns user friendly strings without 478 min bug', () {
      expect(PhilippineTimeHelper.formatRemaining(Duration.zero), '0s');
      expect(PhilippineTimeHelper.formatRemaining(const Duration(seconds: 45)), '45s');
      expect(PhilippineTimeHelper.formatRemaining(const Duration(minutes: 3, seconds: 12)), '3 min 12s');
      expect(PhilippineTimeHelper.formatRemaining(const Duration(hours: 2, minutes: 15)), '2h 15m');
    });

    test('10. formatDateTime and formatDate produce clean Philippine date strings', () {
      final formatted = PhilippineTimeHelper.formatDateTime('2026-10-20T16:52:00');
      expect(formatted, 'Oct 20 at 4:52 PM');

      final dateFormatted = PhilippineTimeHelper.formatDate('2026-10-20T16:52:00');
      expect(dateFormatted, 'Oct 20, 2026 at 4:52 PM');
    });
  });
}
