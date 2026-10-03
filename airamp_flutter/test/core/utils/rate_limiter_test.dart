import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/utils/rate_limiter.dart';
import 'package:airamp_flutter/src/core/api/rate_limit_interceptor.dart';
import 'package:dio/dio.dart';

void main() {
  group('RateLimiter tests', () {
    late RateLimiter limiter;

    setUp(() {
      limiter = RateLimiter();
      limiter.reset('test_cooldown');
      limiter.reset('test_window');
      limiter.reset('test_lockout');
    });

    test('enforces cooldown between consecutive requests', () {
      final res1 = limiter.checkAndRecord(
        'test_cooldown',
        maxRequests: 5,
        window: const Duration(minutes: 1),
        cooldown: const Duration(seconds: 2),
      );
      expect(res1.isAllowed, isTrue);

      final res2 = limiter.checkAndRecord(
        'test_cooldown',
        maxRequests: 5,
        window: const Duration(minutes: 1),
        cooldown: const Duration(seconds: 2),
      );
      expect(res2.isAllowed, isFalse);
      expect(res2.retryAfter.inSeconds, inInclusiveRange(1, 2));
      expect(res2.message, contains('Please wait'));
    });

    test('enforces sliding window limits', () {
      for (int i = 0; i < 3; i++) {
        final res = limiter.checkAndRecord(
          'test_window',
          maxRequests: 3,
          window: const Duration(seconds: 10),
        );
        expect(res.isAllowed, isTrue, reason: 'Request $i should be permitted');
      }

      // 4th request should exceed window limit
      final resExceeded = limiter.checkAndRecord(
        'test_window',
        maxRequests: 3,
        window: const Duration(seconds: 10),
      );
      expect(resExceeded.isAllowed, isFalse);
      expect(resExceeded.message, contains('Rate limit reached'));
    });

    test('tracks consecutive failures and locks out on threshold', () {
      expect(limiter.isLockedOut('test_lockout'), isFalse);

      // Record 4 failures
      for (int i = 0; i < 4; i++) {
        limiter.recordFailure(
          'test_lockout',
          maxFailures: 5,
          lockoutDuration: const Duration(minutes: 10),
        );
        expect(limiter.isLockedOut('test_lockout'), isFalse);
      }

      // 5th failure should trigger lockout
      limiter.recordFailure(
        'test_lockout',
        maxFailures: 5,
        lockoutDuration: const Duration(minutes: 10),
      );
      expect(limiter.isLockedOut('test_lockout'), isTrue);
      expect(limiter.getRemainingLockout('test_lockout').inSeconds, greaterThan(0));

      // Actions should be blocked by checkAndRecord during lockout
      final blocked = limiter.checkAndRecord(
        'test_lockout',
        maxRequests: 10,
        window: const Duration(minutes: 1),
      );
      expect(blocked.isAllowed, isFalse);
      expect(blocked.message, contains('Please wait'));

      // Reset clears the lockout
      limiter.reset('test_lockout');
      expect(limiter.isLockedOut('test_lockout'), isFalse);
    });
  });

  group('RateLimitInterceptor tests', () {
    test('rejects rapid bursts exceeding limit with 429 status', () async {
      final dio = Dio();
      dio.interceptors.add(RateLimitInterceptor());

      // Attempt rapid burst beyond maxPerSecond
      int rejectedCount = 0;
      for (int i = 0; i < RateLimitInterceptor.maxPerSecond + 5; i++) {
        try {
          await dio.get('https://example.invalid/ping');
        } on DioException catch (e) {
          if (e.response?.statusCode == 429) {
            rejectedCount++;
          }
        }
      }

      expect(rejectedCount, greaterThan(0), reason: 'Burst requests beyond limit should trigger 429');
    });
  });
}
