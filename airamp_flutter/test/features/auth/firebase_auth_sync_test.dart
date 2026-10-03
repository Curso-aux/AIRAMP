import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Firebase & SQLite Unified Authentication Tests', () {
    final repo = AuthRepository();

    test('Super Admin 1 can login with aira@admin', () async {
      final res = await repo.login('aira@admin', 'aira@admin');
      expect(res['user']['role'], anyOf('super_admin', 'admin'));
      expect(res['session'], isNotEmpty);
    });

    test('Super Admin 2 can login with superadmin@aira.edu', () async {
      final res = await repo.login('superadmin@aira.edu', 'SuperAdmin@123');
      expect(res['user']['role'], 'super_admin');
      expect(res['session'], isNotEmpty);
    });

    test('School Admin can login with admin@aira.edu', () async {
      final res = await repo.login('admin@aira.edu', 'Admin@123');
      expect(res['user']['role'], 'admin');
      expect(res['session'], isNotEmpty);
    });

    test('Teacher 1 can login with teacher1@aira.edu', () async {
      final res = await repo.login('teacher1@aira.edu', 'Teacher@123');
      expect(res['user']['role'], 'teacher');
      expect(res['session'], isNotEmpty);
    });

    test('Teacher Sir John Reyes can login with john.reyes@deped.gov.ph', () async {
      final res = await repo.login('john.reyes@deped.gov.ph', 'John@123');
      expect(res['user']['role'], 'teacher');
      expect(res['session'], isNotEmpty);
    });

    test('Student 1 can login with student1@aira.edu', () async {
      final res = await repo.login('student1@aira.edu', 'Student@123');
      expect(res['user']['role'], 'student');
      expect(res['session'], isNotEmpty);
    });

    test('Student Maria Lopez can login with maria@test.com', () async {
      final res = await repo.login('maria@test.com', 'Maria@123');
      expect(res['user']['role'], 'student');
      expect(res['session'], isNotEmpty);
    });

    test('Student Juan Dela Cruz can login with juan.delacruz@school.edu', () async {
      final res = await repo.login('juan.delacruz@school.edu', 'Juan@123');
      expect(res['user']['role'], 'student');
      expect(res['session'], isNotEmpty);
    });
  });
}
