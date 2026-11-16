import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Teacher Activity Roster correctly reflects student submission and file attachment', () async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final teacherId = 'T_teacher_$now';
    final studentId = 'S_student_$now';
    final cloudAssignId = 'assign_${now}_project_sync';

    // 1. Seed users
    await db.insert('users', {
      'id': teacherId,
      'email': 'teacher_$now@school.edu',
      'username': 'teacher_$now',
      'password': 'hashed_password',
      'role': 'teacher',
      'full_name': 'Prof. Test Teacher',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('users', {
      'id': studentId,
      'email': 'student_$now@school.edu',
      'username': 'student_$now',
      'password': 'hashed_password',
      'role': 'student',
      'full_name': 'Curso Submitter',
      'section': 'Grade 12 - Sapphire',
      'grade': 'Grade 12',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Seed subject & enrollment
    final subjectId = await db.insert('subjects', {
      'name': 'Mobile UI & State Management',
      'subject_code': 'CS202',
      'description': 'Mobile UI course',
      'teacher_id': teacherId,
      'teacher_name': 'Prof. Test Teacher',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('enrollments', {
      'student_id': studentId,
      'subject_id': subjectId,
      'enrolled_at': DateTime.now().toIso8601String(),
    });

    // 3. Create assignment
    final assignmentId = await dbHelper.createAssignment(
      title: 'gg',
      subjectId: subjectId,
      teacherId: teacherId,
      cloudId: cloudAssignId,
      dueDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
    );

    // 4. Initial check: student has NOT submitted yet
    var roster = await dbHelper.getActivityRosterForTeacher(assignmentId);
    expect(roster.length, equals(1));
    expect(roster.first['student_id'], equals(studentId));
    expect(roster.first['computed_status'], equals('not submitted'));

    // 5. Simulate student submitting assignment
    final r2StorageUrl = 'https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev/submissions/assign_$assignmentId/Group_No_5_CaseStudy_POBLACION.pdf';
    await dbHelper.submitAssignment(
      assignmentId: assignmentId,
      studentId: studentId,
      studentName: 'Curso Submitter',
      submissionType: 'file',
      fileName: 'Group_No_5_CaseStudy_POBLACION.pdf',
      fileSize: 268117,
      storageUrl: r2StorageUrl,
      notes: 'Final case study report submitted.',
    );

    // 6. Teacher checks roster: student status MUST be 'submitted'
    roster = await dbHelper.getActivityRosterForTeacher(assignmentId);
    expect(roster.length, equals(1));
    final studentRow = roster.first;
    expect(studentRow['student_id'], equals(studentId));
    expect(studentRow['computed_status'], equals('submitted'));
    expect(studentRow['submission_id'], isNotNull);
    expect(studentRow['file_name'], equals('Group_No_5_CaseStudy_POBLACION.pdf'));
    expect(studentRow['storage_url'], equals(r2StorageUrl));
    expect(studentRow['notes'], equals('Final case study report submitted.'));

    // 7. Teacher grades student submission
    await dbHelper.gradeSubmission(
      submissionId: studentRow['submission_id'] as int,
      grade: 98.5,
      feedback: 'Excellent work!',
      gradedBy: teacherId,
    );

    // 8. Re-check roster: student status MUST be 'graded'
    roster = await dbHelper.getActivityRosterForTeacher(assignmentId);
    expect(roster.first['computed_status'], equals('graded'));
    expect(roster.first['grade'], equals(98.5));
    expect(roster.first['feedback'], equals('Excellent work!'));
  });

  test('syncCloudSubmissionsToLocal resolves cloud_id and links submission to local assignment', () async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final teacherId = 'T_teacher2_$now';
    final studentId = 'S_student2_$now';
    final cloudAssignId = 'assign_${now}_cloud_sync_test';

    // 1. Seed users & subject
    await db.insert('users', {
      'id': teacherId,
      'email': 't2_$now@school.edu',
      'username': 't2_$now',
      'password': 'hashed_password',
      'role': 'teacher',
      'full_name': 'Teacher 2',
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('users', {
      'id': studentId,
      'email': 's2_$now@school.edu',
      'username': 's2_$now',
      'password': 'hashed_password',
      'role': 'student',
      'full_name': 'Curso Cloud Student',
      'section': 'Grade 12 - Sapphire',
      'created_at': DateTime.now().toIso8601String(),
    });

    final subjectId = await db.insert('subjects', {
      'name': 'Cloud Subjects',
      'subject_code': 'CS_CLOUD',
      'description': 'Description',
      'teacher_id': teacherId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.insert('enrollments', {
      'student_id': studentId,
      'subject_id': subjectId,
      'enrolled_at': DateTime.now().toIso8601String(),
    });

    // 2. Create local assignment with cloud_id
    final assignmentId = await dbHelper.createAssignment(
      title: 'Cloud Assignment Test',
      subjectId: subjectId,
      teacherId: teacherId,
      cloudId: cloudAssignId,
    );

    // 3. Simulate directly inserting a cloud submission row (as would be retrieved from Supabase)
    await db.insert('submissions', {
      'assignment_id': assignmentId,
      'assignment_cloud_id': cloudAssignId,
      'student_id': studentId,
      'student_name': 'Curso Cloud Student',
      'student_section': 'Grade 12 - Sapphire',
      'submission_type': 'file',
      'file_name': 'Group_No_5_CaseStudy_POBLACION.pdf',
      'file_size': 268117,
      'storage_url': 'https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev/submissions/assign_$assignmentId/file.pdf',
      'submitted_at': DateTime.now().toIso8601String(),
      'status': 'submitted',
    });

    // 4. Verify getActivityRosterForTeacher links it via assignment_id OR assignment_cloud_id
    final roster = await dbHelper.getActivityRosterForTeacher(assignmentId);
    expect(roster.length, equals(1));
    expect(roster.first['student_id'], equals(studentId));
    expect(roster.first['computed_status'], equals('submitted'));
    expect(roster.first['file_name'], equals('Group_No_5_CaseStudy_POBLACION.pdf'));
    expect(roster.first['storage_url'], contains('file.pdf'));
  });
}
