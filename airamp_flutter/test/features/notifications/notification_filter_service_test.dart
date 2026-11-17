import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/notifications/domain/notification_filter_service.dart';

void main() {
  late NotificationFilterService filterService;

  setUp(() {
    filterService = NotificationFilterService();
    filterService.reset();
  });

  group('NotificationFilterService Unit Tests', () {
    test('computeFingerprint is deterministic and sensitive to parameters', () {
      final fp1 = filterService.computeFingerprint(
        userId: 'student_101',
        type: 'new_assignment',
        title: 'Math Homework 1',
        relatedId: 'assign_99',
        actorId: 'teacher_1',
      );

      final fp2 = filterService.computeFingerprint(
        userId: 'student_101',
        type: 'new_assignment',
        title: 'Math Homework 1',
        relatedId: 'assign_99',
        actorId: 'teacher_1',
      );

      final fpDifferentTitle = filterService.computeFingerprint(
        userId: 'student_101',
        type: 'new_assignment',
        title: 'Math Homework 2',
        relatedId: 'assign_99',
        actorId: 'teacher_1',
      );

      final fpDifferentUser = filterService.computeFingerprint(
        userId: 'student_102',
        type: 'new_assignment',
        title: 'Math Homework 1',
        relatedId: 'assign_99',
        actorId: 'teacher_1',
      );

      expect(fp1, equals(fp2), reason: 'Identical parameters must produce identical SHA-256 fingerprint');
      expect(fp1, isNot(equals(fpDifferentTitle)), reason: 'Different title must produce different fingerprint');
      expect(fp1, isNot(equals(fpDifferentUser)), reason: 'Different user must produce different fingerprint');
      expect(fp1.length, equals(64), reason: 'SHA-256 hex string must be 64 characters long');
    });

    test('deduplicates identical activity events within active window', () {
      final now = DateTime.now();

      // First evaluation should pass
      final eval1 = filterService.evaluate(
        userId: 'student_101',
        type: 'activity_submission',
        title: 'Submitted Project A',
        eventTime: now,
        relatedId: 'proj_1',
        actorId: 'student_101',
        dedupWindow: const Duration(minutes: 10),
      );

      expect(eval1.shouldPersist, isTrue);
      expect(eval1.shouldAlert, isTrue);
      expect(eval1.isDuplicate, isFalse);

      // Second identical evaluation within window should be suppressed as duplicate
      final eval2 = filterService.evaluate(
        userId: 'student_101',
        type: 'activity_submission',
        title: 'Submitted Project A',
        eventTime: now.add(const Duration(seconds: 30)),
        relatedId: 'proj_1',
        actorId: 'student_101',
        dedupWindow: const Duration(minutes: 10),
      );

      expect(eval2.shouldPersist, isFalse);
      expect(eval2.shouldAlert, isFalse);
      expect(eval2.isDuplicate, isTrue);
      expect(eval2.reason, contains('Duplicate'));
    });

    test('suppresses alerts for historical/stale activity events older than 24 hours', () {
      final oldEventTime = DateTime.now().subtract(const Duration(hours: 25));

      final eval = filterService.evaluate(
        userId: 'teacher_01',
        type: 'announcement',
        title: 'Old School Bulletin',
        eventTime: oldEventTime,
        staleWindow: const Duration(hours: 24),
      );

      // Stale events are persisted silently to SQLite for history, but suppressed from push/in-app alert banners
      expect(eval.shouldPersist, isTrue);
      expect(eval.shouldAlert, isFalse);
      expect(eval.isStale, isTrue);
      expect(eval.isDuplicate, isFalse);
      expect(eval.reason, contains('Stale historical event'));
    });

    test('rate limits rapid successive notifications to prevent spam and flooding', () {
      final now = DateTime.now();

      // Send 5 rapid notifications with maxBurstPerWindow = 3
      final evaluations = <NotificationEvaluation>[];
      for (int i = 0; i < 5; i++) {
        final eval = filterService.evaluate(
          userId: 'flooded_user',
          type: 'chat',
          title: 'Message $i',
          eventTime: now,
          relatedId: 'conv_$i',
          maxBurstPerWindow: 3,
          burstWindow: const Duration(seconds: 10),
          cooldown: Duration.zero,
        );
        evaluations.add(eval);
      }

      // First 3 should alert
      expect(evaluations[0].shouldAlert, isTrue);
      expect(evaluations[1].shouldAlert, isTrue);
      expect(evaluations[2].shouldAlert, isTrue);

      // 4th and 5th exceed the burst window of 3 -> rate limited
      expect(evaluations[3].isRateLimited, isTrue);
      expect(evaluations[3].shouldAlert, isFalse);
      expect(evaluations[3].shouldPersist, isTrue); // still persisted so user does not lose record

      expect(evaluations[4].isRateLimited, isTrue);
      expect(evaluations[4].shouldAlert, isFalse);
    });

    test('cooldown prevents burst flooding within minimum interval', () {
      final now = DateTime.now();

      // First notification passes
      final eval1 = filterService.evaluate(
        userId: 'cooldown_user',
        type: 'quiz_submitted',
        title: 'Quiz 1',
        eventTime: now,
        relatedId: 'q1',
        maxBurstPerWindow: 10,
        burstWindow: const Duration(minutes: 1),
        cooldown: const Duration(seconds: 3),
      );
      expect(eval1.shouldAlert, isTrue);

      // Instant second notification within cooldown window is rate-limited
      final eval2 = filterService.evaluate(
        userId: 'cooldown_user',
        type: 'quiz_submitted',
        title: 'Quiz 2',
        eventTime: now,
        relatedId: 'q2',
        maxBurstPerWindow: 10,
        burstWindow: const Duration(minutes: 1),
        cooldown: const Duration(seconds: 3),
      );
      expect(eval2.isRateLimited, isTrue);
      expect(eval2.shouldAlert, isFalse);
    });
  });
}
