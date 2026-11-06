import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/utils/web_session_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Web Session Persistence & Reload Tests', () {
    test('WebSessionHelper correctly exposes interface methods', () {
      expect(WebSessionHelper.hasActiveSession(), isNotNull);
      WebSessionHelper.markSessionActive('user_123');
      WebSessionHelper.saveSession(
        userId: 'user_123',
        role: 'admin',
        token: 'test_token',
        mustChangePassword: false,
      );
      WebSessionHelper.saveUserProfile({
        'id': 'user_123',
        'email': 'admin@aira.edu',
        'role': 'admin',
        'fullName': 'Admin User',
      });
      WebSessionHelper.clearSession();
    });

    test('bootstrap restores user and session properly', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final testUserId = 'student_refresh_test';
      await db.delete('sessions');
      await db.insert('sessions', {
        'user_id': testUserId,
        'token': 'aira_sec_refresh_token',
        'role': 'student',
        'must_change_password': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('users', {
        'id': testUserId,
        'email': 'student_refresh@example.com',
        'role': 'student',
        'full_name': 'Refresh Student',
        'password': 'hashed_pass',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).bootstrap();
      final restored = container.read(authProvider);

      expect(restored, isNotNull);
      expect(restored!.id, equals(testUserId));
      expect(restored.fullName, equals('Refresh Student'));
      expect(restored.role, equals('student'));
    });
  });
}

