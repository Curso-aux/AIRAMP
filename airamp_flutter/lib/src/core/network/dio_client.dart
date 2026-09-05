import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();

  // You can set the base URL to your Cloudflare Worker URL
  dio.options.baseUrl = 'https://api.your-cloudflare-worker.com/v1'; // TODO: Update with real URL
  dio.options.connectTimeout = const Duration(seconds: 15);
  dio.options.receiveTimeout = const Duration(seconds: 15);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth headers if needed here.
        // e.g. token from secure storage or ref.read(authProvider)
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors here
        return handler.next(e);
      },
    ),
  );

  return dio;
});
