import 'package:dio/dio.dart';
import 'package:airamp_flutter/src/core/api/auth_headers.dart';

class ApiClient {
  static const String _functionsUrl = String.fromEnvironment(
    'FUNCTIONS_URL',
    defaultValue: '',
  );

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _functionsUrl.isEmpty ? 'https://example.invalid/api' : _functionsUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  static String? _session;
  static String? _userId;

  static Dio get instance => _dio;

  static void setSession({String? session, String? userId}) {
    _session = session;
    _userId = userId;
  }

  static void clearSession() {
    _session = null;
    _userId = null;
  }

  static bool get hasSession => _session != null && _userId != null;

  static InterceptorsWrapper authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_session != null && _userId != null) {
          options.headers.addAll(
            AuthHeaders.build(session: _session!, userId: _userId!),
          );
        }
        handler.next(options);
      },
    );
  }

  static bool get isCloudAvailable => _functionsUrl.isNotEmpty;
}
