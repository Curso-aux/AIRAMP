import 'package:dio/dio.dart';
import '../utils/rate_limiter.dart';

/// Global client-side rate limit interceptor for [Dio] requests.
///
/// Throttles outgoing HTTP traffic to prevent accidental client-side request loops,
/// spamming, or triggering server-side 429 penalties.
class RateLimitInterceptor extends Interceptor {
  final RateLimiter _limiter = RateLimiter();

  // Global thresholds across all API requests
  static const int maxPerSecond = 10;
  static const int maxPerMinute = 120;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.uri.path;

    // 1. Check burst rate limit (per-second cap)
    final burstCheck = _limiter.checkAndRecord(
      'global_burst',
      maxRequests: maxPerSecond,
      window: const Duration(seconds: 1),
    );

    if (!burstCheck.isAllowed) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 429,
            statusMessage: 'Client-side rate limit exceeded: Too many rapid requests.',
            data: {
              'error': 'Too many rapid requests.',
              'retry_after_seconds': burstCheck.retryAfterSeconds,
              'message': burstCheck.message,
            },
          ),
        ),
      );
      return;
    }

    // 2. Check rolling minute rate limit (per-minute cap)
    final minuteCheck = _limiter.checkAndRecord(
      'global_minute',
      maxRequests: maxPerMinute,
      window: const Duration(minutes: 1),
    );

    if (!minuteCheck.isAllowed) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: 429,
            statusMessage: 'Client-side rate limit exceeded: Minute cap reached.',
            data: {
              'error': 'Minute request threshold reached.',
              'retry_after_seconds': minuteCheck.retryAfterSeconds,
              'message': minuteCheck.message,
            },
          ),
        ),
      );
      return;
    }

    // 3. Endpoint-specific throttling (e.g. email sending / sensitive endpoints)
    if (path.contains('/send-email') || path.contains('/send') || path.contains('/email')) {
      final emailCheck = _limiter.checkAndRecord(
        'endpoint_email',
        maxRequests: 5,
        window: const Duration(minutes: 1),
        cooldown: const Duration(seconds: 5),
      );

      if (!emailCheck.isAllowed) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: 429,
              statusMessage: 'Email dispatch rate limit reached.',
              data: {
                'error': 'Too many email requests in a short time.',
                'retry_after_seconds': emailCheck.retryAfterSeconds,
                'message': emailCheck.message,
              },
            ),
          ),
        );
        return;
      }
    }

    handler.next(options);
  }
}
