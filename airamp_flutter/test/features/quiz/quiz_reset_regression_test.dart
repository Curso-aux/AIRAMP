import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('P0 Quiz Reset Regression Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. Reset after completion: clears quiz_attempts, resets assignment to pending, deletes student_progress, allows retake', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_reset_$now';
      final studentId = 'student_reset_$now';
      final db = await dbHelper.database;

      // Seed teacher and student
      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'Password123',
        'role': 'teacher',
        'full_name': 'Teacher Reset',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student Reset',
        'section': 'Section Reset',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Seed subject & LO
      final subjectId = await db.insert('subjects', {
        'name': 'Reset Science $now',
        'subject_code': 'RST-$now',
        'description': 'Reset Science Description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final topicId = await db.insert('topics', {
        'subject_id': subjectId,
        'title': 'Reset Topic',
        'created_at': DateTime.now().toIso8601String(),
      });

      final loId = await db.insert('learning_outcomes', {
        'topic_id': topicId,
        'title': 'Reset LO',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Teacher creates quiz tied to loId
      final quizId = await dbHelper.createQuiz(
        title: 'Photosynthesis Quiz $now',
        subjectId: subjectId,
        teacherId: teacherId,
        loId: loId,
        timeLimitMinutes: 10,
        passingScore: 70,
        questions: [
          {
            'question_text': 'Q1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'A',
          },
          {
            'question_text': 'Q2',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'B',
          },
        ],
      );

      // Assign quiz to student
      await dbHelper.assignQuizToStudents(quizId: quizId, studentIds: [studentId]);

      // Verify assignment starts pending
      var studentQuizzes = await dbHelper.getAssignedQuizzesForStudent(studentId, subjectId: subjectId);
      expect(studentQuizzes.first['status'], equals('pending'));
      expect(studentQuizzes.first['score'], equals(0));

      // Student completes quiz with 100%
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: loId,
        quizId: quizId,
        subjectId: subjectId,
        score: 2,
        totalQuestions: 2,
        percentage: 100.0,
        isPassed: true,
        durationSeconds: 90,
      );

      // Verify attempts, assignments, and student_progress are populated
      var attempts = await db.query('quiz_attempts', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(attempts, hasLength(1));

      var assignments = await db.query('quiz_assignments', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(assignments.first['status'], equals('completed'));
      expect(assignments.first['score'], equals(2));

      var progress = await db.query('student_progress', where: 'student_id = ? AND lo_id = ?', whereArgs: [studentId, loId]);
      expect(progress, hasLength(1));
      expect(progress.first['is_completed'], equals(1));

      // Verify canAttempt is false prior to reset
      var canAttemptBeforeReset = await dbHelper.hasStudentCompletedQuiz(studentId: studentId, quizId: quizId);
      expect(canAttemptBeforeReset, isFalse);

      // Teacher / Student triggers Reset
      await dbHelper.resetStudentQuizAttempt(quizId: quizId, studentId: studentId);

      // Verify quiz_attempts is deleted
      attempts = await db.query('quiz_attempts', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(attempts, isEmpty);

      // Verify quiz_assignments is reset to pending with 0 score
      assignments = await db.query('quiz_assignments', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(assignments.first['status'], equals('pending'));
      expect(assignments.first['score'], equals(0));
      expect(assignments.first['total_questions'], equals(0));
      expect(assignments.first['percentage'], equals(0.0));
      expect(assignments.first['completed_at'], isNull);

      // Verify student_progress is deleted for the associated LO
      progress = await db.query('student_progress', where: 'student_id = ? AND lo_id = ?', whereArgs: [studentId, loId]);
      expect(progress, isEmpty);

      // Verify canAttempt is now true after reset
      var canAttemptAfterReset = await dbHelper.hasStudentCompletedQuiz(studentId: studentId, quizId: quizId);
      expect(canAttemptAfterReset, isTrue);

      // Student retakes quiz without throwing duplicate attempt exception
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: loId,
        quizId: quizId,
        subjectId: subjectId,
        score: 1,
        totalQuestions: 2,
        percentage: 50.0,
        isPassed: false,
        durationSeconds: 120,
      );

      // Verify new attempt is recorded
      attempts = await db.query('quiz_attempts', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(attempts, hasLength(1));
      expect(attempts.first['score'], equals(1));
      expect(attempts.first['is_passed'], equals(0));

      assignments = await db.query('quiz_assignments', where: 'quiz_id = ? AND student_id = ?', whereArgs: [quizId, studentId]);
      expect(assignments.first['status'], equals('completed'));
      expect(assignments.first['score'], equals(1));
    });

    test('2. Teacher roster calculates Passed/Failed/Pending based on percentage vs passing_score', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_roster_$now';
      final studentPass = 'student_pass_$now';
      final studentFail = 'student_fail_$now';
      final studentPending = 'student_pending_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'Password123',
        'role': 'teacher',
        'full_name': 'Teacher Roster',
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final s in [studentPass, studentFail, studentPending]) {
        await db.insert('users', {
          'id': s,
          'email': '$s@school.edu',
          'username': s,
          'password': 'Password123',
          'role': 'student',
          'full_name': 'Student $s',
          'section': 'Section Roster',
          'grade': 'Grade 10',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final subjectId = await db.insert('subjects', {
        'name': 'Roster Math $now',
        'subject_code': 'MTH-$now',
        'description': 'Roster Math Description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Passing score is 70%
      final quizId = await dbHelper.createQuiz(
        title: 'Math Roster Quiz $now',
        subjectId: subjectId,
        teacherId: teacherId,
        passingScore: 70,
        questions: [
          {
            'question_text': '2+2?',
            'option_a': '4',
            'option_b': '5',
            'option_c': '6',
            'option_d': '7',
            'correct_option': 'A',
          },
          {
            'question_text': '3+3?',
            'option_a': '6',
            'option_b': '7',
            'option_c': '8',
            'option_d': '9',
            'correct_option': 'A',
          },
        ],
      );

      await dbHelper.assignQuizToStudents(
        quizId: quizId,
        studentIds: [studentPass, studentFail, studentPending],
      );

      // StudentPass gets 2/2 (100% >= 70%) -> raw score 2, percentage 100
      await dbHelper.completeQuizAssignment(
        quizId: quizId,
        studentId: studentPass,
        score: 2,
        totalQuestions: 2,
        percentage: 100.0,
      );

      // StudentFail gets 1/2 (50% < 70%) -> raw score 1, percentage 50
      await dbHelper.completeQuizAssignment(
        quizId: quizId,
        studentId: studentFail,
        score: 1,
        totalQuestions: 2,
        percentage: 50.0,
      );

      // StudentPending does not complete

      final roster = await dbHelper.getQuizAssignmentRoster(quizId);
      expect(roster, hasLength(3));

      final passRow = roster.firstWhere((r) => r['student_id'] == studentPass);
      expect(passRow['result'], equals('Passed'));
      expect(passRow['status'], equals('completed'));

      final failRow = roster.firstWhere((r) => r['student_id'] == studentFail);
      expect(failRow['result'], equals('Failed'));
      expect(failRow['status'], equals('completed'));

      final pendingRow = roster.firstWhere((r) => r['student_id'] == studentPending);
      expect(pendingRow['result'], equals('Pending'));
      expect(pendingRow['status'], equals('pending'));

      // Now reset studentPass from roster
      await dbHelper.resetStudentQuizAttempt(quizId: quizId, studentId: studentPass);

      final rosterAfterReset = await dbHelper.getQuizAssignmentRoster(quizId);
      final resetRow = rosterAfterReset.firstWhere((r) => r['student_id'] == studentPass);
      expect(resetRow['result'], equals('Pending'));
      expect(resetRow['status'], equals('pending'));
      expect(resetRow['score'], equals(0));
    });

    test('3. Resetting LO quiz directly clears quiz_attempts and student_progress', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_lo_reset_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student LO Reset',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'LO Subject $now',
        'subject_code': 'LO-$now',
        'description': 'LO Subject Description',
        'created_at': DateTime.now().toIso8601String(),
      });

      final topicId = await db.insert('topics', {
        'subject_id': subjectId,
        'title': 'Topic LO',
        'created_at': DateTime.now().toIso8601String(),
      });

      final loId = await db.insert('learning_outcomes', {
        'topic_id': topicId,
        'title': 'Standalone LO Quiz',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Record LO attempt directly
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: loId,
        quizId: null,
        subjectId: subjectId,
        score: 3,
        totalQuestions: 3,
        percentage: 100.0,
        isPassed: true,
      );

      var attempts = await db.query('quiz_attempts', where: 'lo_id = ? AND student_id = ?', whereArgs: [loId, studentId]);
      expect(attempts, hasLength(1));

      var progress = await db.query('student_progress', where: 'lo_id = ? AND student_id = ?', whereArgs: [loId, studentId]);
      expect(progress, hasLength(1));

      // Reset LO attempt
      await dbHelper.resetStudentLoQuizAttempt(loId: loId, studentId: studentId);

      attempts = await db.query('quiz_attempts', where: 'lo_id = ? AND student_id = ?', whereArgs: [loId, studentId]);
      expect(attempts, isEmpty);

      progress = await db.query('student_progress', where: 'lo_id = ? AND student_id = ?', whereArgs: [loId, studentId]);
      expect(progress, isEmpty);
    });
  });
}
