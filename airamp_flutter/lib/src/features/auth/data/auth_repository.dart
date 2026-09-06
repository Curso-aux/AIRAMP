import '../../../core/database/database_helper.dart';

class AuthRepository {
  // Dio kept for future backend calls but not used for local auth
  AuthRepository(dynamic dio);

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final db = await DatabaseHelper().database;
    final identifierLower = identifier.toLowerCase().trim();

    // Search by email or full_name (case-insensitive)
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
    return {
      'user': {
        'id': user['id'],
        'email': user['email'],
        'role': user['role'],
        'fullName': user['full_name'],
      }
    };
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await DatabaseHelper().database;

    // Check if email already exists
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

  Future<void> logout() async {
    // No-op for local auth; will clear tokens for real backend later
  }
}
