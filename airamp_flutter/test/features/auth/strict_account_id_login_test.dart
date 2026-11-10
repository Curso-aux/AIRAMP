import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Option A: Strict Account ID Login Enforcement Tests', () {
    final repo = AuthRepository();

    test('Attempting to log in with an email address is strictly rejected', () async {
      expect(
        () => repo.login('student@deped.gov.ph', 'Password@123'),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Wrong User ID. ID only.')),
        ),
      );
    });

    test('Attempting to log in with any @ string is immediately blocked before querying', () async {
      expect(
        () => repo.login('admin@aira.edu', 'Admin@123'),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Wrong User ID. ID only.')),
        ),
      );
    });

    test('Super admin can log in strictly using assigned Account ID SA-000-0001', () async {
      // Ensure super admin account exists in test db
      final db = await DatabaseHelper().database;
      final salt = DatabaseHelper.generateSalt();
      final hash = DatabaseHelper.hashPassword('Admin@123', salt);
      await db.insert(
        'users',
        {
          'id': 'SA-000-0001',
          'email': 'evangelistachristian88@gmail.com',
          'full_name': 'Super Admin',
          'role': 'super_admin',
          'password': hash,
          'password_salt': salt,
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final res = await repo.login('SA-000-0001', 'Admin@123');
      expect(res['user']['id'], 'SA-000-0001');
      expect(res['user']['role'], 'super_admin');
    });

    test('Invalid User ID fails with clean error message', () async {
      expect(
        () => repo.login('S-999-9999', 'AnyPassword123'),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('Wrong User ID or password')),
        ),
      );
    });
  });
}
