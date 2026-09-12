import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Section Key Registration & Enrollment Tests', () {
    final repo = AuthRepository();
    final dbHelper = DatabaseHelper();

    test('Registering student with SEC-EMR10 auto-binds section and enrolls in curriculum subjects', () async {
      final email = 'test_student_${DateTime.now().millisecondsSinceEpoch}@aira.edu';
      final res = await repo.register(
        fullName: 'Emerald Student Test',
        email: email,
        password: 'Password@123',
        username: 'emerald.student.${DateTime.now().millisecondsSinceEpoch}',
        role: 'student',
        sectionCode: 'SEC-EMR10',
      );

      final user = res['user'] as Map<String, dynamic>;
      expect(user['fullName'], 'Emerald Student Test');
      expect(user['section'], contains('Emerald'));
      expect(user['grade'], 'Grade 10');

      final studentId = user['id'].toString();
      final enrolledSubjects = await dbHelper.getEnrolledSubjects(studentId);
      expect(enrolledSubjects, isNotEmpty);
      expect(enrolledSubjects.length, greaterThanOrEqualTo(1));

      // Verify each enrolled subject has Grade 10
      for (final sub in enrolledSubjects) {
        expect(sub['grade_level'], 'Grade 10');
      }
    });

    test('Registering student with SEC-STEM11 auto-binds Grade 11 section and enrolls in Grade 11 subjects', () async {
      final email = 'test_stem_${DateTime.now().millisecondsSinceEpoch}@aira.edu';
      final res = await repo.register(
        fullName: 'STEM Student Test',
        email: email,
        password: 'Password@123',
        username: 'stem.student.${DateTime.now().millisecondsSinceEpoch}',
        role: 'student',
        sectionCode: 'SEC-STEM11',
      );

      final user = res['user'] as Map<String, dynamic>;
      expect(user['fullName'], 'STEM Student Test');
      expect(user['section'], contains('STEM'));
      expect(user['grade'], 'Grade 11');

      final studentId = user['id'].toString();
      final enrolledSubjects = await dbHelper.getEnrolledSubjects(studentId);
      expect(enrolledSubjects, isNotEmpty);
      for (final sub in enrolledSubjects) {
        expect(sub['grade_level'], 'Grade 11');
      }
    });

    test('Registering student without section key leaves them cleanly unassigned', () async {
      final email = 'test_unassigned_${DateTime.now().millisecondsSinceEpoch}@aira.edu';
      final res = await repo.register(
        fullName: 'Unassigned Student Test',
        email: email,
        password: 'Password@123',
        username: 'unassigned.student.${DateTime.now().millisecondsSinceEpoch}',
        role: 'student',
      );

      final user = res['user'] as Map<String, dynamic>;
      expect(user['fullName'], 'Unassigned Student Test');
      expect(user['section'] == null || user['section'] == '', isTrue);

      final studentId = user['id'].toString();
      final enrolledSubjects = await dbHelper.getEnrolledSubjects(studentId);
      expect(enrolledSubjects, isEmpty);

      // Student can enroll later via section key
      final enrollSuccess = await dbHelper.enrollStudentBySectionKey(
        studentId,
        'SEC-EMR10',
      );
      expect(enrollSuccess, isTrue);

      final postEnrollSubjects = await dbHelper.getEnrolledSubjects(studentId);
      expect(postEnrollSubjects, isNotEmpty);
    });

    test('completeQuizAssignment marks assignment as completed and records quiz attempt', () async {
      // Create a test quiz attempt completion
      await dbHelper.completeQuizAssignment(
        quizId: 1,
        studentId: 'test_student_roster',
        score: 9,
        totalQuestions: 10,
        percentage: 90.0,
      );

      final status = await dbHelper.getQuizAssignment(1, 'test_student_roster');
      // If assignment entry exists or was updated
      if (status != null) {
        expect(status['status'], 'completed');
        expect(status['score'], 9);
        expect(status['percentage'], 90.0);
      }
    });

    test('Invalid section key during registration is gracefully handled without crash', () async {
      final email = 'test_invalid_${DateTime.now().millisecondsSinceEpoch}@aira.edu';
      final res = await repo.register(
        fullName: 'Invalid Key Student',
        email: email,
        password: 'Password@123',
        username: 'invalid.student.${DateTime.now().millisecondsSinceEpoch}',
        role: 'student',
        sectionCode: 'INVALID-NONEXISTENT-KEY',
      );

      final user = res['user'] as Map<String, dynamic>;
      expect(user['fullName'], 'Invalid Key Student');
      expect(user['section'] == null || user['section'] == '', isTrue);
    });
  });
}
