import 'package:dio/dio.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/api/api_client.dart';

class AuthSession {
  final String session;
  final String userId;
  final String role;
  AuthSession({required this.session, required this.userId, required this.role});
}

class AuthRepository {
  final Dio _dio;
  AuthRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final db = await DatabaseHelper().database;
    final identifierLower = identifier.toLowerCase().trim();

    final results = await db.rawQuery(
      '''SELECT * FROM users
         WHERE (LOWER(email) = ? OR LOWER(full_name) = ?)
         AND password = ?''',
      [identifierLower, identifierLower, password],
    );

    if (results.isEmpty) {
      throw Exception('Invalid email/username or password.');
    }

    final user = results.first;
    final userId = user['id'] as String;
    final role = user['role'] as String;

    String token = _localToken(userId);

    if (ApiClient.isCloudAvailable) {
      try {
        final resp = await _dio.post(
          '/v1/auth/session',
          options: Options(
            headers: {
              'X-School-Session': token,
              'X-School-User-Id': userId,
            },
          ),
        );
        final data = resp.data;
        if (data is Map && data['token'] is String) {
          token = data['token'] as String;
        }
      } on DioException {
        // Fall through with local token
      }
    }

    await _persistSession(userId: userId, role: role, token: token);
    ApiClient.setSession(session: token, userId: userId);

    return {
      'user': {
        'id': userId,
        'email': user['email'],
        'role': role,
        'fullName': user['full_name'],
      },
      'session': token,
    };
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await DatabaseHelper().database;

    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );

    if (existing.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    final id = '${role}_${DateTime.now().millisecondsSinceEpoch}';

    await db.insert('users', {
      'id': id,
      'email': email.trim(),
      'password': password,
      'role': role,
      'full_name': fullName.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    return {
      'user': {
        'id': id,
        'email': email.trim(),
        'role': role,
        'fullName': fullName.trim(),
      }
    };
  }

  Future<AuthSession?> currentSession() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('sessions', orderBy: 'id DESC', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return AuthSession(
      session: r['token'] as String,
      userId: r['user_id'] as String,
      role: r['role'] as String,
    );
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? email,
    String? profileImage,
    String? password,
  }) async {
    if (ApiClient.isCloudAvailable) {
      try {
        await _dio.put('/v1/api/users/$userId', data: {
          if (fullName != null) 'fullName': fullName,
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (profileImage != null) 'profileImage': profileImage,
          if (password != null) 'password': password,
        });
      } on DioException {
        // Fall through; local SQLite is already updated via authProvider
      }
    }
  }

  Future<void> logout() async {
    final db = await DatabaseHelper().database;
    final session = await currentSession();
    if (session != null && ApiClient.isCloudAvailable) {
      try {
        await _dio.post(
          '/v1/auth/revoke',
          options: Options(
            headers: {
              'X-School-Session': session.session,
              'X-School-User-Id': session.userId,
            },
          ),
        );
      } on DioException {
        // ignore network errors during logout
      }
    }
    await db.delete('sessions');
    ApiClient.clearSession();
  }

  Future<void> _persistSession({
    required String userId,
    required String role,
    required String token,
  }) async {
    final db = await DatabaseHelper().database;
    await db.delete('sessions');
    await db.insert('sessions', {
      'user_id': userId,
      'token': token,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  String _localToken(String userId) {
    return 'local-$userId-${DateTime.now().millisecondsSinceEpoch}';
  }
}
