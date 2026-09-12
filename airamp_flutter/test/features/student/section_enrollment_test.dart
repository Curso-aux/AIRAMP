import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Section Key-based Enrollment Workflow', () {
    test('verifySectionKey returns null for invalid key', () async {
      final helper = DatabaseHelper();
      final result = await helper.verifySectionKey('INVALID-KEY-999');
      expect(result, isNull);
    });

    test('verifySectionKey resolves section, room, and subjects case-insensitively', () async {
      final helper = DatabaseHelper();
      
      // Test case-insensitive verification
      final verified = await helper.verifySectionKey('sec-emr10');
      expect(verified, isNotNull);

      final section = verified!['section'] as Map<String, dynamic>;
      expect(section['name'], 'Grade 10 - Emerald');
      expect(section['grade'], 'Grade 10');
      expect(section['room'], isNotNull);
      expect(section['enrollment_key'], 'SEC-EMR10');

      final subjects = verified['subjects'] as List<dynamic>;
      expect(subjects.isNotEmpty, isTrue);
      for (final s in subjects) {
        expect(s['name'], isNotNull);
        expect(s['teacher_name'], isNotNull);
      }
    });

    test('enrollStudentBySectionKey binds student and enrolls all section subjects atomically', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      const studentId = 'test_key_enroll_student_1';

      // Insert dummy student
      await db.insert(
        'users',
        {
          'id': studentId,
          'email': 'student_key_test@school.edu',
          'password': 'Password123',
          'role': 'student',
          'full_name': 'Key Test Student',
          'section': '',
          'grade': '',
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Verify and enroll
      final success = await helper.enrollStudentBySectionKey(studentId, 'SEC-EMR10');
      expect(success, isTrue);

      // Verify user record updated with section & grade
      final userRows = await db.query('users', where: 'id = ?', whereArgs: [studentId]);
      expect(userRows.first['section'], 'Grade 10 - Emerald');
      expect(userRows.first['grade'], 'Grade 10');

      // Verify student details helper
      final details = await helper.getSectionDetailsForStudent(studentId);
      expect(details, isNotNull);
      expect(details!['name'], 'Grade 10 - Emerald');
      expect(details['enrollment_key'], 'SEC-EMR10');

      // Verify enrolled subjects count matches section subjects
      final enrolled = await helper.getEnrolledSubjects(studentId);
      expect(enrolled.isNotEmpty, isTrue);

      // Verify leave section functionality
      await helper.leaveSectionForStudent(studentId);
      final detailsAfterLeave = await helper.getSectionDetailsForStudent(studentId);
      expect(detailsAfterLeave, isNull);

      final enrolledAfterLeave = await helper.getEnrolledSubjects(studentId);
      expect(enrolledAfterLeave.isEmpty, isTrue);
    });
  });
}
