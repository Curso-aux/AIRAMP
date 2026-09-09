import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/student/data/student_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 1: Security Hardening & Session Integrity Tests', () {
    final authRepo = AuthRepository();

    test('1. DatabaseHelper password hashing produces non-trivial salted hash', () {
      final salt1 = DatabaseHelper.generateSalt();
      final salt2 = DatabaseHelper.generateSalt();
      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2)));

      final hash1 = DatabaseHelper.hashPassword('MySecretPass@123', salt1);
      final hash2 = DatabaseHelper.hashPassword('MySecretPass@123', salt2);
      expect(hash1, isNot(equals('MySecretPass@123')));
      expect(hash1, isNot(equals(hash2)));

      expect(DatabaseHelper.verifyPassword('MySecretPass@123', hash1, salt1), isTrue);
      expect(DatabaseHelper.verifyPassword('WrongPass', hash1, salt1), isFalse);
      expect(DatabaseHelper.verifyPassword('MySecretPass@123', hash1, salt2), isFalse);
    });

    test('2. Seed accounts in database have salted SHA-256 hashes and non-empty salts', () async {
      final db = await DatabaseHelper().database;
      final users = await db.query('users');
      expect(users, isNotEmpty);

      for (final u in users) {
        final pass = u['password'] as String;
        final salt = u['password_salt'] as String?;
        expect(salt, isNotNull);
        expect(salt, isNotEmpty);
        // Salted SHA-256 produces a 64-character hex string
        expect(pass.length, equals(64));
      }
    });

    test('3. Login returns cryptographically secure random session tokens', () async {
      final res = await authRepo.login('aira@admin', 'aira@admin');
      final session = res['session'] as String;
      expect(session, startsWith('aira_sec_admin_1_'));
      // Prefix aira_sec_admin_1_ (17 chars) + 64 hex chars = 81 chars
      expect(session.length, greaterThanOrEqualTo(80));

      final res2 = await authRepo.login('aira@admin', 'aira@admin');
      final session2 = res2['session'] as String;
      expect(session, isNot(equals(session2)), reason: 'Tokens must be cryptographically unique random values');
    });

    test('4. Registering a new account stores salted password and non-empty salt', () async {
      final testEmail = 'security_test_${DateTime.now().millisecondsSinceEpoch}@school.edu';
      final res = await authRepo.register(
        fullName: 'Security Test Student',
        email: testEmail,
        password: 'Password@999',
        role: 'student',
      );

      final newUserId = res['user']['id'] as String;
      final db = await DatabaseHelper().database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: [newUserId]);
      expect(rows, isNotEmpty);

      final storedPass = rows.first['password'] as String;
      final storedSalt = rows.first['password_salt'] as String?;

      expect(storedSalt, isNotNull);
      expect(storedSalt, isNotEmpty);
      expect(storedPass.length, equals(64));
      expect(storedPass, isNot(equals('Password@999')));
      expect(DatabaseHelper.verifyPassword('Password@999', storedPass, storedSalt), isTrue);
    });

    test('5. Legacy unhashed user account is auto-migrated on successful login', () async {
      final db = await DatabaseHelper().database;
      final legacyId = 'legacy_user_${DateTime.now().millisecondsSinceEpoch}';
      final legacyEmail = '$legacyId@school.edu';

      // Insert plaintext user with null salt
      await db.insert('users', {
        'id': legacyId,
        'email': legacyEmail,
        'username': legacyId,
        'password': 'PlaintextPass@123',
        'password_salt': null,
        'role': 'student',
        'full_name': 'Legacy Student',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Login with plaintext credentials
      final loginRes = await authRepo.login(legacyEmail, 'PlaintextPass@123');
      expect(loginRes['user']['id'], equals(legacyId));

      // Check that password in DB was migrated to salted hash
      final updatedRows = await db.query('users', where: 'id = ?', whereArgs: [legacyId]);
      final updatedPass = updatedRows.first['password'] as String;
      final updatedSalt = updatedRows.first['password_salt'] as String?;

      expect(updatedSalt, isNotNull);
      expect(updatedSalt, isNotEmpty);
      expect(updatedPass.length, equals(64));
      expect(updatedPass, isNot(equals('PlaintextPass@123')));
      expect(DatabaseHelper.verifyPassword('PlaintextPass@123', updatedPass, updatedSalt), isTrue);
    });

    test('6. Student and Teacher repositories do not leak seed data when unauthenticated', () async {
      final container = ProviderContainer();
      expect(container.read(authProvider), isNull);

      // Student courses should be empty, NOT Maria Lopez's enrolled courses
      final studentCourses = container.read(studentCoursesProvider);
      expect(studentCourses, isEmpty);

      // Student progress summary should be clean defaults with 0 completed
      final studentProgress = container.read(studentProgressProvider);
      expect(studentProgress['completed'], equals(0));
      expect(studentProgress['activeCourses'], equals(0));

      // Teacher dashboard should be empty, NOT Sir John's stats
      final teacherDashboard = container.read(teacherDashboardProvider);
      expect(teacherDashboard, isEmpty);

      // Teacher students should be empty, NOT Sir John's student roster
      final teacherStudents = container.read(teacherStudentsProvider);
      expect(teacherStudents, isEmpty);

      container.dispose();
    });
  });
}
