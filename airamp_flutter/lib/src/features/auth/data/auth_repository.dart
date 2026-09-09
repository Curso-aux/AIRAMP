import 'dart:math';
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

    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    } catch (_) {}

    // Find candidate accounts by email, username, full name, or name prefix
    List<Map<String, Object?>> candidateRows = [];
    try {
      candidateRows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(email) = ? 
              OR LOWER(COALESCE(username, '')) = ?
              OR LOWER(full_name) = ?
              OR LOWER(REPLACE(REPLACE(COALESCE(username, ''), '.', ' '), '_', ' ')) = ?
              OR LOWER(full_name) LIKE ?
              OR LOWER(COALESCE(username, '')) LIKE ?''',
        [identifierLower, identifierLower, identifierLower, identifierLower, '$identifierLower%', '$identifierLower%'],
      );
    } catch (_) {
      candidateRows = await db.rawQuery(
        '''SELECT * FROM users
           WHERE LOWER(email) = ? 
              OR LOWER(full_name) = ?
              OR LOWER(full_name) LIKE ?''',
        [identifierLower, identifierLower, '$identifierLower%'],
      );
    }

    if (candidateRows.isEmpty) {
      throw Exception('Invalid email/username or password.');
    }

    // Verify password with salted hash or verify & auto-upgrade legacy plaintext
    final List<Map<String, Object?>> verifiedUsers = [];
    for (final candidate in candidateRows) {
      final storedHash = candidate['password'] as String? ?? '';
      final storedSalt = candidate['password_salt'] as String?;

      if (DatabaseHelper.verifyPassword(password, storedHash, storedSalt)) {
        // Auto-upgrade legacy plaintext accounts to salted SHA-256 on successful login
        if (storedSalt == null || storedSalt.isEmpty) {
          final newSalt = DatabaseHelper.generateSalt();
          final newHash = DatabaseHelper.hashPassword(password, newSalt);
          await db.update('users', {
            'password': newHash,
            'password_salt': newSalt,
          }, where: 'id = ?', whereArgs: [candidate['id']]);
        }
        verifiedUsers.add(candidate);
      }
    }

    if (verifiedUsers.isEmpty) {
      throw Exception('Invalid email/username or password.');
    }

    // If multiple accounts match, prioritize exact email/username and faculty roles over student
    final sorted = List<Map<String, Object?>>.from(verifiedUsers);
    if (sorted.length > 1) {
      sorted.sort((a, b) {
        final aEmail = (a['email'] as String? ?? '').toLowerCase();
        final bEmail = (b['email'] as String? ?? '').toLowerCase();
        final aUser = (a['username'] as String? ?? '').toLowerCase();
        final bUser = (b['username'] as String? ?? '').toLowerCase();
        final aExact = aEmail == identifierLower || aUser == identifierLower;
        final bExact = bEmail == identifierLower || bUser == identifierLower;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        final aRole = a['role'] as String? ?? '';
        final bRole = b['role'] as String? ?? '';
        if (aRole != 'student' && bRole == 'student') return -1;
        if (aRole == 'student' && bRole != 'student') return 1;
        return 0;
      });
    }

    final user = sorted.first;
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
        'username': user['username'] ?? user['full_name'] ?? '',
        'section': user['section'],
        'grade': user['grade'],
      },
      'session': token,
    };
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? username,
    String? sectionCode,
  }) async {
    final db = await DatabaseHelper().database;

    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}

    final existingEmail = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );

    if (existingEmail.isNotEmpty) {
      throw Exception('An account with this email already exists.');
    }

    if (username != null && username.trim().isNotEmpty) {
      final existingUser = await db.query(
        'users',
        where: 'LOWER(COALESCE(username, "")) = ?',
        whereArgs: [username.toLowerCase().trim()],
      );
      if (existingUser.isNotEmpty) {
        throw Exception('An account with this username already exists.');
      }
    }

    final id = '${role}_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedUsername = username?.trim().isNotEmpty == true
        ? username!.trim()
        : (email.contains('@') ? email.split('@').first : fullName.trim());

    final salt = DatabaseHelper.generateSalt();
    final hashedPassword = DatabaseHelper.hashPassword(password, salt);

    final userData = {
      'id': id,
      'email': email.trim(),
      'username': resolvedUsername,
      'password': hashedPassword,
      'password_salt': salt,
      'role': role,
      'full_name': fullName.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // If student and section code provided, validate and bind
    String? assignedSection;
    String? assignedGrade;
    if (role == 'student' && sectionCode != null && sectionCode.trim().isNotEmpty) {
      final codeTrimmed = sectionCode.trim();
      final linkRow = await db.query('reg_links', where: 'code = ?', whereArgs: [codeTrimmed]);
      if (linkRow.isNotEmpty) {
        assignedSection = linkRow.first['section'] as String?;
        if (assignedSection != null && assignedSection.isNotEmpty) {
          final secRow = await db.query('sections', where: 'name = ?', whereArgs: [assignedSection]);
          if (secRow.isNotEmpty) {
            assignedGrade = secRow.first['grade'] as String?;
          }
        }
      }
    }

    if (assignedSection != null) {
      userData['section'] = assignedSection;
    }
    if (assignedGrade != null) {
      userData['grade'] = assignedGrade;
    }

    await db.insert('users', userData);

    if (role == 'student' && sectionCode != null && sectionCode.trim().isNotEmpty) {
      await DatabaseHelper().validateAndConsumeRegistrationKey(sectionCode.trim(), id);
      if (assignedSection != null && assignedSection.isNotEmpty) {
        await DatabaseHelper().autoEnrollStudentBySection(id, assignedSection, assignedGrade ?? '');
      }
    }

    final token = _localToken(id);
    await _persistSession(userId: id, role: role, token: token);
    ApiClient.setSession(session: token, userId: id);

    return {
      'user': {
        'id': id,
        'email': email.trim(),
        'username': resolvedUsername,
        'role': role,
        'fullName': fullName.trim(),
        'section': assignedSection,
        'grade': assignedGrade,
      },
      'session': token,
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
    final db = await DatabaseHelper().database;
    final updates = <String, Object?>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (email != null) updates['email'] = email;
    if (password != null && password.isNotEmpty) {
      final salt = DatabaseHelper.generateSalt();
      updates['password'] = DatabaseHelper.hashPassword(password, salt);
      updates['password_salt'] = salt;
    }
    if (updates.isNotEmpty) {
      try {
        await db.update('users', updates, where: 'id = ?', whereArgs: [userId]);
      } catch (_) {}
    }

    if (ApiClient.isCloudAvailable) {
      try {
        await _dio.put('/v1/api/users/$userId', data: {
          'fullName': ?fullName,
          'username': ?username,
          'email': ?email,
          'profileImage': ?profileImage,
          'password': ?password,
        });
      } on DioException {
        // Fall through; local SQLite is already updated
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
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    final tokenHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'aira_sec_${userId}_$tokenHex';
  }
}
