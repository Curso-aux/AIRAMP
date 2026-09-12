import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Submissions & Assignments Database Tests (v20)', () {
    final dbHelper = DatabaseHelper();

    test('1. Database v20 schema contains assignments and submissions tables', () async {
      final db = await dbHelper.database;
      final tableNamesRes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('assignments', 'submissions')",
      );
      final names = tableNamesRes.map((r) => r['name'] as String).toList();
      expect(names.contains('assignments'), isTrue);
      expect(names.contains('submissions'), isTrue);
    });

    test('2. Teacher creates assignment and student sees it in their subject tasks', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_sub_$now';
      final studentId = 'student_sub_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'hashed_pass',
        'role': 'teacher',
        'full_name': 'Teacher Submissions Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'hashed_pass',
        'role': 'student',
        'full_name': 'Student Submissions Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Mobile App Dev $now',
        'subject_code': 'MAD-$now',
        'description': 'Mobile application development course',
        'teacher_id': teacherId,
        'teacher_name': 'Teacher Submissions Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Project 1: Flutter State Management',
        description: 'Build a Riverpod counter with persistence and file attachment.',
        subjectId: subjectId,
        teacherId: teacherId,
        teacherName: 'Teacher Submissions Tester',
        dueDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        totalPoints: 100,
        submissionType: 'both',
      );

      expect(assignmentId, isPositive);

      final fetched = await dbHelper.getAssignmentById(assignmentId);
      expect(fetched, isNotNull);
      expect(fetched!['title'], 'Project 1: Flutter State Management');
      expect(fetched['total_points'], 100);
      expect(fetched['subject_name'], 'Mobile App Dev $now');

      final studentTasks = await dbHelper.getAssignmentsForStudent(studentId, subjectId: subjectId);
      expect(studentTasks.length, 1);
      expect(studentTasks.first['id'], assignmentId);
      expect(studentTasks.first['submission_status'], isNull); // Pending
    });

    test('3. Student submits project link and file attachment', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_sub_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'password': 'pass',
        'role': 'student',
        'full_name': 'Jane Student',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Web Dev $now',
        'subject_code': 'WEB-$now',
        'description': 'Web development test subject',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Responsive Design Lab',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        dueDate: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      );

      final subId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: 'Jane Student',
        submissionType: 'both',
        contentLink: 'https://github.com/janestudent/responsive-lab',
        fileName: 'project_bundle.zip',
        fileSize: 450200,
        filePath: '/tmp/project_bundle.zip',
        notes: 'Includes dark mode and unit tests.',
      );

      expect(subId, isPositive);

      final sub = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(sub, isNotNull);
      expect(sub!['content_link'], 'https://github.com/janestudent/responsive-lab');
      expect(sub['file_name'], 'project_bundle.zip');
      expect(sub['file_size'], 450200);
      expect(sub['notes'], 'Includes dark mode and unit tests.');
      expect(sub['status'], 'submitted');

      // Check student assignments listing reflects submission
      final studentTasks = await dbHelper.getAssignmentsForStudent(studentId, subjectId: subjectId);
      expect(studentTasks.first['submission_status'], 'submitted');
    });

    test('4. Resubmission updates existing submission without duplicate records', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_resub_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'password': 'pass',
        'role': 'student',
        'full_name': 'Resub Student',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Cloud Computing $now',
        'subject_code': 'CC-$now',
        'description': 'Cloud computing test subject',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Microservices Deployment',
        subjectId: subjectId,
        teacherId: 'teacher_1',
      );

      // First submission
      await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        submissionType: 'link',
        contentLink: 'https://github.com/test/v1',
      );

      // Second submission (update)
      await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        submissionType: 'link',
        contentLink: 'https://github.com/test/v2',
        notes: 'Updated to v2 with bug fixes.',
      );

      final allSubs = await dbHelper.getSubmissionsForAssignment(assignmentId);
      expect(allSubs.length, 1);
      expect(allSubs.first['content_link'], 'https://github.com/test/v2');
      expect(allSubs.first['notes'], 'Updated to v2 with bug fixes.');
    });

    test('5. Teacher grades submission and feedback reflects for student', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_grade_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'password': 'pass',
        'role': 'student',
        'full_name': 'Student To Grade',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Cybersecurity $now',
        'subject_code': 'CYB-$now',
        'description': 'Cybersecurity test subject',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Penetration Testing Report',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        totalPoints: 100,
      );

      final subId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        submissionType: 'file',
        fileName: 'security_audit_report.pdf',
        fileSize: 1024000,
      );

      // Teacher grades the submission
      final rowsUpdated = await dbHelper.gradeSubmission(
        submissionId: subId,
        grade: 96.5,
        feedback: 'Outstanding vulnerability analysis and mitigation steps!',
        gradedBy: 'Sir John Reyes',
      );

      expect(rowsUpdated, 1);

      // Verify from student perspective
      final studentSubmission = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(studentSubmission, isNotNull);
      expect(studentSubmission!['status'], 'graded');
      expect(studentSubmission['grade'], 96.5);
      expect(studentSubmission['feedback'], 'Outstanding vulnerability analysis and mitigation steps!');
      expect(studentSubmission['graded_by'], 'Sir John Reyes');

      // Verify subject summary stats
      final subjectAssignments = await dbHelper.getAssignmentsForSubject(subjectId);
      expect(subjectAssignments.first['submission_count'], 1);
      expect(subjectAssignments.first['graded_count'], 1);
    });

    test('6. Deleting assignment cascades and removes associated submissions', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = await dbHelper.database;

      final subjectId = await db.insert('subjects', {
        'name': 'Cascade Test $now',
        'subject_code': 'CAS-$now',
        'description': 'Cascade test subject',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Temporary Assignment',
        subjectId: subjectId,
        teacherId: 'teacher_1',
      );

      await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: 'test_student_$now',
        submissionType: 'link',
        contentLink: 'https://test.link',
      );

      expect((await dbHelper.getSubmissionsForAssignment(assignmentId)).length, 1);

      await dbHelper.deleteAssignment(assignmentId);

      expect(await dbHelper.getAssignmentById(assignmentId), isNull);
      expect((await dbHelper.getSubmissionsForAssignment(assignmentId)).isEmpty, isTrue);
    });
  });
}
