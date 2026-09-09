import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AuthRepository Username and Email Support Tests', () {
    final repo = AuthRepository();

    test('Log in using Admin username: "Aira Admin"', () async {
      final res = await repo.login('Aira Admin', 'aira@admin');
      expect(res['user']['role'], 'super_admin');
      expect(res['user']['email'], 'aira@admin');
      expect(res['user']['fullName'], 'Aira Admin');
      expect(res['user']['username'], 'Aira Admin');
    });

    test('Log in using Admin email: "aira@admin"', () async {
      final res = await repo.login('aira@admin', 'aira@admin');
      expect(res['user']['role'], 'super_admin');
      expect(res['user']['email'], 'aira@admin');
    });

    test('Log in using Admin username lowercase: "aira admin"', () async {
      final res = await repo.login('aira admin', 'aira@admin');
      expect(res['user']['role'], 'super_admin');
    });

    test('Log in using secondary Admin username: "admin"', () async {
      final res = await repo.login('admin', 'Admin@123');
      expect(res['user']['role'], 'admin');
      expect(res['user']['email'], 'admin@aira.edu');
    });

    test('Log in using secondary Admin email: "admin@aira.edu"', () async {
      final res = await repo.login('admin@aira.edu', 'Admin@123');
      expect(res['user']['role'], 'admin');
    });

    test('Log in using Teacher username: "john.reyes"', () async {
      final res = await repo.login('john.reyes', 'John@123');
      expect(res['user']['role'], 'teacher');
    });

    test('Log in using Teacher username alias: "Sir John"', () async {
      final res = await repo.login('Sir John', 'John@123');
      expect(res['user']['role'], 'teacher');
      expect(res['user']['email'], 'john.reyes@deped.gov.ph');
    });

    test('Log in using Teacher full name: "Sir John Reyes"', () async {
      final res = await repo.login('Sir John Reyes', 'John@123');
      expect(res['user']['role'], 'teacher');
      expect(res['user']['email'], 'john.reyes@deped.gov.ph');
    });

    test('Log in using Student username: "maria.lopez"', () async {
      final res = await repo.login('maria.lopez', 'Maria@123');
      expect(res['user']['role'], 'student');
    });

    test('Log in using Student full name / username: "Maria Lopez"', () async {
      final res = await repo.login('Maria Lopez', 'Maria@123');
      expect(res['user']['role'], 'student');
      expect(res['user']['email'], 'maria@test.com');
    });

    test('Throws on invalid password', () async {
      expect(
        () => repo.login('Aira Admin', 'wrongpassword'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
