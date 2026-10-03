import 'dart:math';

/// Result object returned by [RateLimiter] checks.
class RateLimitResult {
  final bool isAllowed;
  final int remainingAttempts;
  final Duration retryAfter;
  final String message;

  const RateLimitResult({
    required this.isAllowed,
    required this.remainingAttempts,
    required this.retryAfter,
    required this.message,
  });

  int get retryAfterSeconds => max(1, retryAfter.inSeconds);
  int get retryAfterMinutes => max(1, (retryAfter.inSeconds / 60).ceil());
}

/// Centralized in-memory sliding-window and cooldown rate limiter.
///
/// Supports:
/// 1. Cooldown limits (minimum delay between subsequent requests)
/// 2. Sliding-window limits (maximum N requests per rolling time window)
/// 3. Temporary lockouts on repeated failures (e.g. 5 failed PIN attempts)
class RateLimiter {
  static final RateLimiter _instance = RateLimiter._internal();
  factory RateLimiter() => _instance;
  RateLimiter._internal();

  final Map<String, List<DateTime>> _requestLogs = {};
  final Map<String, DateTime> _lastRequestTimes = {};
  final Map<String, DateTime> _lockouts = {};
  final Map<String, String> _lockoutReasons = {};
  final Map<String, int> _failureCounters = {};

  /// Checks if an action on [key] is allowed under the given constraints.
  /// If allowed, records the action automatically.
  RateLimitResult checkAndRecord(
    String key, {
    required int maxRequests,
    required Duration window,
    Duration? cooldown,
  }) {
    final now = DateTime.now();
    final normalizedKey = key.toLowerCase().trim();

    // 1. Check if key is in active lockout
    final lockoutEnd = _lockouts[normalizedKey];
    if (lockoutEnd != null) {
      if (now.isBefore(lockoutEnd)) {
        final remaining = lockoutEnd.difference(now);
        final reason = _lockoutReasons[normalizedKey] ?? 'Too many attempts.';
        final waitSecs = max(1, remaining.inSeconds);
        final waitMins = max(1, (waitSecs / 60).ceil());
        final timeText = waitSecs >= 60 ? '$waitMins minute(s)' : '$waitSecs second(s)';
        return RateLimitResult(
          isAllowed: false,
          remainingAttempts: 0,
          retryAfter: remaining,
          message: '$reason Please wait $timeText before trying again.',
        );
      } else {
        _lockouts.remove(normalizedKey);
        _lockoutReasons.remove(normalizedKey);
        _failureCounters.remove(normalizedKey);
      }
    }

    // 2. Check cooldown between consecutive requests
    if (cooldown != null) {
      final lastTime = _lastRequestTimes[normalizedKey];
      if (lastTime != null) {
        final elapsed = now.difference(lastTime);
        if (elapsed < cooldown) {
          final wait = cooldown - elapsed;
          final waitSecs = max(1, wait.inSeconds);
          return RateLimitResult(
            isAllowed: false,
            remainingAttempts: 0,
            retryAfter: wait,
            message: 'Please wait ${waitSecs}s before making another request.',
          );
        }
      }
    }

    // 3. Sliding window check
    final history = _requestLogs[normalizedKey] ?? [];
    final cutoff = now.subtract(window);
    history.removeWhere((timestamp) => timestamp.isBefore(cutoff));
    _requestLogs[normalizedKey] = history;

    if (history.length >= maxRequests) {
      final oldest = history.first;
      final retryAfter = oldest.add(window).difference(now);
      final waitSecs = max(1, retryAfter.inSeconds);
      final waitMins = max(1, (waitSecs / 60).ceil());
      final timeText = waitSecs >= 60 ? '$waitMins minute(s)' : '$waitSecs second(s)';

      return RateLimitResult(
        isAllowed: false,
        remainingAttempts: 0,
        retryAfter: retryAfter,
        message: 'Rate limit reached (max $maxRequests per ${window.inMinutes}m). Please wait $timeText.',
      );
    }

    // Allowed: record request
    history.add(now);
    _lastRequestTimes[normalizedKey] = now;
    final remaining = max(0, maxRequests - history.length);

    return RateLimitResult(
      isAllowed: true,
      remainingAttempts: remaining,
      retryAfter: Duration.zero,
      message: 'OK',
    );
  }

  /// Records a failed attempt for [key]. If failures reach [maxFailures],
  /// locks out the key for [lockoutDuration].
  void recordFailure(
    String key, {
    int maxFailures = 5,
    Duration lockoutDuration = const Duration(minutes: 15),
    String reason = 'Too many failed verification attempts.',
  }) {
    final normalizedKey = key.toLowerCase().trim();
    final current = (_failureCounters[normalizedKey] ?? 0) + 1;
    _failureCounters[normalizedKey] = current;

    if (current >= maxFailures) {
      final now = DateTime.now();
      _lockouts[normalizedKey] = now.add(lockoutDuration);
      _lockoutReasons[normalizedKey] = reason;
      _failureCounters.remove(normalizedKey);
    }
  }

  /// Manually locks out a key for [duration].
  void lockout(String key, Duration duration, {String reason = 'Temporarily locked out.'}) {
    final normalizedKey = key.toLowerCase().trim();
    final now = DateTime.now();
    _lockouts[normalizedKey] = now.add(duration);
    _lockoutReasons[normalizedKey] = reason;
  }

  /// Resets all counters and lockouts for [key].
  void reset(String key) {
    final normalizedKey = key.toLowerCase().trim();
    _requestLogs.remove(normalizedKey);
    _lastRequestTimes.remove(normalizedKey);
    _lockouts.remove(normalizedKey);
    _lockoutReasons.remove(normalizedKey);
    _failureCounters.remove(normalizedKey);
  }

  /// Checks if [key] is currently locked out without recording a request.
  bool isLockedOut(String key) {
    final normalizedKey = key.toLowerCase().trim();
    final lockoutEnd = _lockouts[normalizedKey];
    if (lockoutEnd == null) return false;
    if (DateTime.now().isBefore(lockoutEnd)) return true;
    _lockouts.remove(normalizedKey);
    _lockoutReasons.remove(normalizedKey);
    return false;
  }

  /// Returns remaining time if locked out, or [Duration.zero].
  Duration getRemainingLockout(String key) {
    final normalizedKey = key.toLowerCase().trim();
    final lockoutEnd = _lockouts[normalizedKey];
    if (lockoutEnd == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isBefore(lockoutEnd)) return lockoutEnd.difference(now);
    _lockouts.remove(normalizedKey);
    _lockoutReasons.remove(normalizedKey);
    return Duration.zero;
  }
}
