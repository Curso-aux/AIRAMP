import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/database/firestore_service.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Admin Add Student & Teacher Dual-Database Sync Tests', () {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final testStudentEmail = 'newstudent_$timestamp@school.edu';
    final testTeacherEmail = 'newteacher_$timestamp@school.edu';
    final testPassword = 'Password@123';

    test('Admin adds a new Student: saved to SQLite & Cloud Firestore with category student', () async {
      final dbHelper = DatabaseHelper();
      final studentId = await dbHelper.createStudent(
        fullName: 'Test New Student $timestamp',
        email: testStudentEmail,
        password: testPassword,
        username: 'student_$timestamp',
        grade: 'Grade 10',
        section: 'Diamond',
        studentType: 'regular',
        specialNotes: 'Onboarded via Admin Dashboard',
      );

      expect(studentId, isNotEmpty);

      // Verify in SQLite
      final db = await dbHelper.database;
      final localUser = await db.query('users', where: 'id = ?', whereArgs: [studentId]);
      expect(localUser, isNotEmpty);
      expect(localUser.first['role'], equals('student'));
      expect(localUser.first['full_name'], equals('Test New Student $timestamp'));

      // Verify in Cloud Firestore via findUserByIdentifier
      final cloudUser = await FirestoreService().findUserByIdentifier(testStudentEmail);
      expect(cloudUser, isNotNull);
      expect(cloudUser!['role'], equals('student'));
      expect(cloudUser['category'], equals('student'));

      // Verify newly created student can log in immediately
      final authRepo = AuthRepository();
      final loginResult = await authRepo.login(testStudentEmail, testPassword);
      expect(loginResult['user']['email'], equals(testStudentEmail));
      expect(loginResult['user']['role'], equals('student'));
    });

    test('Admin adds a new Faculty / Teacher: saved to SQLite & Cloud Firestore with category teacher', () async {
      final dbHelper = DatabaseHelper();
      final teacherId = await dbHelper.createTeacher(
        fullName: 'Prof. Test Teacher $timestamp',
        email: testTeacherEmail,
        password: testPassword,
        username: 'prof_$timestamp',
      );

      expect(teacherId, isNotEmpty);

      // Verify in SQLite
      final db = await dbHelper.database;
      final localUser = await db.query('users', where: 'id = ?', whereArgs: [teacherId]);
      expect(localUser, isNotEmpty);
      expect(localUser.first['role'], equals('teacher'));
      expect(localUser.first['full_name'], equals('Prof. Test Teacher $timestamp'));

      // Verify in Cloud Firestore via findUserByIdentifier
      final cloudUser = await FirestoreService().findUserByIdentifier(testTeacherEmail);
      expect(cloudUser, isNotNull);
      expect(cloudUser!['role'], equals('teacher'));
      expect(cloudUser['category'], equals('teacher'));

      // Verify newly created teacher can log in immediately
      final authRepo = AuthRepository();
      final loginResult = await authRepo.login(testTeacherEmail, testPassword);
      expect(loginResult['user']['email'], equals(testTeacherEmail));
      expect(loginResult['user']['role'], equals('teacher'));
    });

    test('Admin adds a student with existing email: updates existing record cleanly without UNIQUE constraint failure', () async {
      final dbHelper = DatabaseHelper();
      final duplicateEmail = 'dup_student_$timestamp@school.edu';

      final id1 = await dbHelper.createStudent(
        fullName: 'Original Student',
        email: duplicateEmail,
        password: 'Password@123',
        grade: 'Grade 10',
        section: 'Diamond',
      );
      expect(id1, isNotEmpty);

      // Attempt creating again with the exact same email
      final id2 = await dbHelper.createStudent(
        fullName: 'Updated Student Name',
        email: duplicateEmail,
        password: 'NewPassword@123',
        grade: 'Grade 12',
        section: 'Ruby',
      );

      expect(id2, equals(id1));

      final db = await dbHelper.database;
      final rows = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [duplicateEmail.toLowerCase()]);
      expect(rows.length, equals(1));
      expect(rows.first['full_name'], equals('Updated Student Name'));
      expect(rows.first['grade'], equals('Grade 12'));
      expect(rows.first['section'], equals('Ruby'));
    });
  });
}
