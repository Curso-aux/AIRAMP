import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../core/utils/rate_limiter.dart';

/// Evaluation result detailing whether a notification should be persisted,
/// displayed as an alert banner/push, or suppressed due to deduplication,
/// staleness, or rate-limiting.
class NotificationEvaluation {
  final bool shouldPersist;
  final bool shouldAlert;
  final bool isDuplicate;
  final bool isStale;
  final bool isRateLimited;
  final String? reason;
  final String fingerprint;

  const NotificationEvaluation({
    required this.shouldPersist,
    required this.shouldAlert,
    required this.isDuplicate,
    required this.isStale,
    required this.isRateLimited,
    this.reason,
    required this.fingerprint,
  });

  @override
  String toString() =>
      'NotificationEvaluation(shouldPersist: $shouldPersist, shouldAlert: $shouldAlert, isDuplicate: $isDuplicate, isStale: $isStale, isRateLimited: $isRateLimited, reason: $reason, fingerprint: $fingerprint)';
}

abstract class INotificationFilterService {
  String computeFingerprint({
    required String userId,
    required String type,
    required String title,
    String? relatedId,
    String? actorId,
  });

  NotificationEvaluation evaluate({
    required String userId,
    required String type,
    required String title,
    required DateTime eventTime,
    String? relatedId,
    String? actorId,
    Duration dedupWindow = const Duration(minutes: 10),
    Duration staleWindow = const Duration(hours: 24),
    int maxBurstPerWindow = 8,
    Duration burstWindow = const Duration(seconds: 60),
    Duration cooldown = const Duration(seconds: 2),
  });

  bool isDuplicate(String fingerprint, {Duration window = const Duration(minutes: 10)});
  bool isStale(DateTime eventTime, {Duration ttl = const Duration(hours: 24)});
  void reset();
}

/// Production implementation of [INotificationFilterService].
/// Provides SHA-256 event fingerprinting, sliding-window deduplication,
/// burst rate-limiting, and historical stale suppression.
class NotificationFilterService implements INotificationFilterService {
  static final NotificationFilterService _instance = NotificationFilterService._internal();
  factory NotificationFilterService() => _instance;
  NotificationFilterService._internal();

  final Map<String, DateTime> _seenFingerprints = {};
  final RateLimiter _rateLimiter = RateLimiter();

  @override
  String computeFingerprint({
    required String userId,
    required String type,
    required String title,
    String? relatedId,
    String? actorId,
  }) {
    final cleanUid = userId.trim().toLowerCase();
    final cleanType = type.trim().toLowerCase();
    final cleanTitle = title.trim();
    final cleanRel = (relatedId ?? '').trim();
    final cleanActor = (actorId ?? '').trim().toLowerCase();

    final rawPayload = '$cleanUid|$cleanType|$cleanTitle|$cleanRel|$cleanActor';
    final bytes = utf8.encode(rawPayload);
    return sha256.convert(bytes).toString();
  }

  @override
  bool isDuplicate(String fingerprint, {Duration window = const Duration(minutes: 10)}) {
    final lastSeen = _seenFingerprints[fingerprint];
    if (lastSeen == null) return false;
    final now = DateTime.now();
    if (now.difference(lastSeen) <= window) {
      return true;
    }
    _seenFingerprints.remove(fingerprint);
    return false;
  }

  @override
  bool isStale(DateTime eventTime, {Duration ttl = const Duration(hours: 24)}) {
    final now = DateTime.now();
    return now.difference(eventTime) > ttl;
  }

  @override
  NotificationEvaluation evaluate({
    required String userId,
    required String type,
    required String title,
    required DateTime eventTime,
    String? relatedId,
    String? actorId,
    Duration dedupWindow = const Duration(minutes: 10),
    Duration staleWindow = const Duration(hours: 24),
    int maxBurstPerWindow = 8,
    Duration burstWindow = const Duration(seconds: 60),
    Duration cooldown = const Duration(seconds: 2),
  }) {
    final fingerprint = computeFingerprint(
      userId: userId,
      type: type,
      title: title,
      relatedId: relatedId,
      actorId: actorId,
    );

    // 1. Deduplication check
    if (isDuplicate(fingerprint, window: dedupWindow)) {
      return NotificationEvaluation(
        shouldPersist: false,
        shouldAlert: false,
        isDuplicate: true,
        isStale: false,
        isRateLimited: false,
        reason: 'Duplicate event suppressed within $dedupWindow window.',
        fingerprint: fingerprint,
      );
    }

    // 2. Stale check (e.g. historical events older than 24h)
    final stale = isStale(eventTime, ttl: staleWindow);
    if (stale) {
      _seenFingerprints[fingerprint] = DateTime.now();
      return NotificationEvaluation(
        shouldPersist: true,
        shouldAlert: false,
        isDuplicate: false,
        isStale: true,
        isRateLimited: false,
        reason: 'Stale historical event older than ${staleWindow.inHours}h (persisted silently).',
        fingerprint: fingerprint,
      );
    }

    // 3. Rate limiting check (sliding window and cooldown)
    final rateLimitKey = 'notif_rate_${userId.trim().toLowerCase()}';
    final rateResult = _rateLimiter.checkAndRecord(
      rateLimitKey,
      maxRequests: maxBurstPerWindow,
      window: burstWindow,
      cooldown: cooldown,
    );

    if (!rateResult.isAllowed) {
      _seenFingerprints[fingerprint] = DateTime.now();
      return NotificationEvaluation(
        shouldPersist: true,
        shouldAlert: false,
        isDuplicate: false,
        isStale: false,
        isRateLimited: true,
        reason: rateResult.message,
        fingerprint: fingerprint,
      );
    }

    // 4. Passed all filters -> persist and trigger alert
    _seenFingerprints[fingerprint] = DateTime.now();
    return NotificationEvaluation(
      shouldPersist: true,
      shouldAlert: true,
      isDuplicate: false,
      isStale: false,
      isRateLimited: false,
      reason: null,
      fingerprint: fingerprint,
    );
  }

  @override
  void reset() {
    _seenFingerprints.clear();
    _rateLimiter.clear();
  }
}
