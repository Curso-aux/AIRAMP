import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = ApiClient.instance;
  // Inject auth interceptor if session available
  dio.interceptors.add(ApiClient.authInterceptor());
  return dio;
});
