import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Feature 3: Activity Submission & Multi-Role Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. Multi-Role Switcher allows switching between student and teacher', () async {
      final user = User(
        id: 'test_user_multirole',
        email: 'multirole@school.edu',
        username: 'multirole_user',
        fullName: 'Multi-Role User',
        role: 'student',
        availableRoles: ['student', 'teacher'],
      );

      expect(user.availableRoles, contains('student'));
      expect(user.availableRoles, contains('teacher'));
      expect(user.role, equals('student'));

      final teacherRoleCopy = user.copyWith(role: 'teacher');
      expect(teacherRoleCopy.role, equals('teacher'));
      expect(teacherRoleCopy.availableRoles, contains('student'));
    });

    test('2. Student submits activity with text, image, and file; teacher gets notified', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_act_$now';
      final studentId = 'student_act_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'hashed_pass',
        'role': 'teacher',
        'full_name': 'Prof. Activity Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'hashed_pass',
        'role': 'student',
        'full_name': 'Alice Submitter',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Science 10 - $now',
        'subject_code': 'SCI-$now',
        'description': 'Science 10 course description',
        'teacher_id': teacherId,
        'teacher_name': 'Prof. Activity Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Enroll student in subject
      await db.insert('enrollments', {
        'student_id': studentId,
        'subject_id': subjectId,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      // Create assignment with future due date (on-time)
      final futureDue = DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final assignmentId = await dbHelper.createAssignment(
        title: 'Laboratory Report: Photosynthesis',
        description: 'Submit your writeup, diagram screenshot, and lab data.',
        subjectId: subjectId,
        teacherId: teacherId,
        teacherName: 'Prof. Activity Tester',
        dueDate: futureDue,
        totalPoints: 100,
        submissionType: 'both',
      );

      // Student submits
      final subId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: 'Alice Submitter',
        submissionType: 'text+image+file+link',
        textResponse: 'This is the complete laboratory writeup detailing light and dark reactions.',
        imagePath: 'photosynthesis_diagram.png',
        fileName: 'lab_raw_data.xlsx',
        fileSize: 24500,
        contentLink: 'https://school-cloud.edu/alice/lab-data',
        notes: 'Please let me know if the excel table needs clarification.',
      );

      expect(subId, isPositive);

      // Verify submission details in DB
      final submission = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(submission, isNotNull);
      expect(submission!['status'], equals('submitted'));
      expect(submission['text_response'], equals('This is the complete laboratory writeup detailing light and dark reactions.'));
      expect(submission['image_path'], equals('photosynthesis_diagram.png'));
      expect(submission['file_name'], equals('lab_raw_data.xlsx'));
      expect(submission['content_link'], equals('https://school-cloud.edu/alice/lab-data'));

      // Verify notification for teacher
      final teacherNotifs = await dbHelper.getNotificationsForUser(teacherId);
      expect(teacherNotifs.isNotEmpty, isTrue);
      final notif = teacherNotifs.first;
      expect(notif['type'], equals('activity_submission'));
      expect(notif['title'], contains('Laboratory Report: Photosynthesis'));
      expect(notif['message'], contains('Alice Submitter'));
      expect(notif['is_read'], equals(0));

      final unreadCount = await dbHelper.getUnreadNotificationCount(teacherId);
      expect(unreadCount, greaterThanOrEqualTo(1));
    });

    test('3. Late submission automatically sets status to late and notifies teacher', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_late_$now';
      final studentId = 'student_late_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'hashed_pass',
        'role': 'teacher',
        'full_name': 'Dr. Deadline',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'hashed_pass',
        'role': 'student',
        'full_name': 'Bob Tardy',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'History 101 - $now',
        'subject_code': 'HIS-$now',
        'description': 'History 101 course description',
        'teacher_id': teacherId,
        'teacher_name': 'Dr. Deadline',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Past due date (yesterday)
      final pastDue = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final assignmentId = await dbHelper.createAssignment(
        title: 'Midterm Research Essay',
        subjectId: subjectId,
        teacherId: teacherId,
        dueDate: pastDue,
        totalPoints: 50,
      );

      // Student submits late
      await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: 'Bob Tardy',
        submissionType: 'text',
        textResponse: 'Here is my midterm essay submission, apologies for the delay.',
      );

      final sub = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(sub, isNotNull);
      expect(sub!['status'], equals('late'));

      // Check notification message indicates Late Submission
      final notifs = await dbHelper.getNotificationsForUser(teacherId);
      expect(notifs.isNotEmpty, isTrue);
      expect(notifs.first['message'], contains('Late Submission'));
    });

    test('4. getActivityRosterForTeacher computes 4-state lifecycle correctly', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_roster_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'pass',
        'role': 'teacher',
        'full_name': 'Faculty Roster Master',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Computer Science - $now',
        'subject_code': 'CS-$now',
        'description': 'Computer Science course description',
        'teacher_id': teacherId,
        'teacher_name': 'Faculty Roster Master',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create 4 students
      final students = ['stu_not_sub_$now', 'stu_sub_$now', 'stu_late_$now', 'stu_graded_$now'];
      for (final sId in students) {
        await db.insert('users', {
          'id': sId,
          'email': '$sId@school.edu',
          'username': sId,
          'password': 'pass',
          'role': 'student',
          'full_name': 'Student $sId',
          'section': 'Section-A',
          'grade': '12',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('enrollments', {
          'student_id': sId,
          'subject_id': subjectId,
          'enrolled_at': DateTime.now().toIso8601String(),
        });
      }

      final futureDue = DateTime.now().add(const Duration(days: 5)).toIso8601String();
      final assignmentId = await dbHelper.createAssignment(
        title: 'Capstone Proposal',
        subjectId: subjectId,
        teacherId: teacherId,
        dueDate: futureDue,
        totalPoints: 100,
      );

      // Student 1: Does not submit -> 'not submitted'

      // Student 2: Submits on-time -> 'submitted'
      await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: students[1],
        studentName: 'Student ${students[1]}',
        submissionType: 'text',
        textResponse: 'Proposal summary on time',
      );

      // Student 3: Submits late by explicitly marking or backdated submission
      final subLateId = await db.insert('submissions', {
        'assignment_id': assignmentId,
        'student_id': students[2],
        'student_name': 'Student ${students[2]}',
        'submission_type': 'file',
        'file_name': 'late_doc.pdf',
        'submitted_at': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
        'status': 'late',
      });
      expect(subLateId, isPositive);

      // Student 4: Submits and gets graded -> 'graded'
      final subGradedId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: students[3],
        studentName: 'Student ${students[3]}',
        submissionType: 'link',
        contentLink: 'https://github.com/stu4/capstone',
      );
      await dbHelper.gradeSubmission(
        submissionId: subGradedId,
        grade: 98.0,
        feedback: 'Outstanding project scope.',
        gradedBy: 'Faculty Roster Master',
      );

      // Query activity roster for teacher
      final roster = await dbHelper.getActivityRosterForTeacher(assignmentId);
      expect(roster.length, equals(4));

      final studentStatuses = {
        for (final r in roster) r['student_id']: r['computed_status']
      };

      expect(studentStatuses[students[0]], equals('not submitted'));
      expect(studentStatuses[students[1]], equals('submitted'));
      expect(studentStatuses[students[2]], equals('late'));
      expect(studentStatuses[students[3]], equals('graded'));
    });

    test('5. Teacher grades submission, student receives notification, mark read works', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_grade_$now';
      final studentId = 'student_grade_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'pass',
        'role': 'teacher',
        'full_name': 'Prof. Evaluation',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'pass',
        'role': 'student',
        'full_name': 'Charlie Learner',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Physics 1 - $now',
        'subject_code': 'PHY-$now',
        'description': 'Physics 1 course description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Newtonian Dynamics Problem Set',
        subjectId: subjectId,
        teacherId: teacherId,
        totalPoints: 100,
      );

      final subId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        studentName: 'Charlie Learner',
        submissionType: 'text',
        textResponse: 'F = ma derivations and friction calculations attached.',
      );

      // Teacher grades
      await dbHelper.gradeSubmission(
        submissionId: subId,
        grade: 94.5,
        feedback: 'Very accurate derivations on problem 3 and 4.',
        gradedBy: 'Prof. Evaluation',
      );

      // Verify submission is graded in DB
      final sub = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(sub, isNotNull);
      expect(sub!['status'], equals('graded'));
      expect(sub['grade'], equals(94.5));
      expect(sub['feedback'], equals('Very accurate derivations on problem 3 and 4.'));
      expect(sub['graded_by'], equals('Prof. Evaluation'));

      // Verify student received notification
      final studentNotifs = await dbHelper.getNotificationsForUser(studentId);
      expect(studentNotifs.isNotEmpty, isTrue);
      final sNotif = studentNotifs.first;
      expect(sNotif['type'], equals('grade_released'));
      expect(sNotif['title'], contains('Newtonian Dynamics Problem Set'));
      expect(sNotif['message'], contains('94.5'));
      expect(sNotif['message'], contains('Very accurate derivations'));

      // Test marking notification as read
      final notifId = sNotif['id'] as String;
      await dbHelper.markNotificationRead(notifId);
      final unreadAfter = await dbHelper.getUnreadNotificationCount(studentId);
      expect(unreadAfter, equals(0));

      // Test markAllNotificationsRead
      await dbHelper.createNotification(
        userId: studentId,
        type: 'test_type',
        title: 'Test Notification',
        message: 'Second test notification',
      );
      expect(await dbHelper.getUnreadNotificationCount(studentId), equals(1));
      await dbHelper.markAllNotificationsRead(studentId);
      expect(await dbHelper.getUnreadNotificationCount(studentId), equals(0));
    });
  });
}
