import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 4: Teacher-to-Student Closed Loop Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. Teacher can create quiz with questions and assign it to student', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_loop_$now';
      final studentId = 'student_loop_$now';
      final db = await dbHelper.database;

      // Seed test teacher and student
      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@deped.gov.ph',
        'username': teacherId,
        'password': 'HashedPassword123',
        'role': 'teacher',
        'full_name': 'Prof Loop Tester',
        'section': 'Section Alpha',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'HashedPassword123',
        'role': 'student',
        'full_name': 'Student Loop Tester',
        'section': 'Section Alpha',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Create subject taught by this teacher
      final subjectId = await db.insert('subjects', {
        'name': 'Loop Science $now',
        'subject_code': 'SCI-$now',
        'description': 'Closed loop testing subject',
        'teacher_id': teacherId,
        'teacher_name': 'Prof Loop Tester',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Enroll student in this subject
      await db.insert('enrollments', {
        'student_id': studentId,
        'subject_id': subjectId,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      // Teacher authors a quiz
      final quizId = await dbHelper.createQuiz(
        title: 'Photosynthesis Master Quiz',
        description: 'Testing cell biology concepts',
        subjectId: subjectId,
        teacherId: teacherId,
        teacherName: 'Prof Loop Tester',
        timeLimitMinutes: 15,
        passingScore: 75,
        dueDate: '2026-12-31',
        questions: [
          {
            'question_text': 'What gas do plants absorb during photosynthesis?',
            'option_a': 'Oxygen',
            'option_b': 'Carbon Dioxide',
            'option_c': 'Nitrogen',
            'option_d': 'Hydrogen',
            'correct_option': 'B',
          },
          {
            'question_text': 'What pigment gives leaves their green color?',
            'option_a': 'Chlorophyll',
            'option_b': 'Carotene',
            'option_c': 'Anthocyanin',
            'option_d': 'Xanthophyll',
            'correct_option': 'A',
          },
        ],
      );

      expect(quizId, greaterThan(0));

      // Teacher assigns quiz to student
      final assignedCount = await dbHelper.assignQuizToStudents(
        quizId: quizId,
        studentIds: [studentId],
        dueDate: '2026-12-31',
      );

      expect(assignedCount, equals(1));

      // 2. Student queries assigned quizzes and sees it as pending
      final studentQuizzes = await dbHelper.getAssignedQuizzesForStudent(studentId, subjectId: subjectId);
      expect(studentQuizzes, hasLength(1));
      final assignedQuiz = studentQuizzes.first;
      expect(assignedQuiz['quiz_id'], equals(quizId));
      expect(assignedQuiz['status'], equals('pending'));
      expect(assignedQuiz['title'], equals('Photosynthesis Master Quiz'));
      expect(assignedQuiz['question_count'], equals(2));
      expect(assignedQuiz['time_limit_minutes'], equals(15));
      expect(assignedQuiz['passing_score'], equals(75));

      // 3. Student completes the quiz
      await dbHelper.completeQuizAssignment(
        quizId: quizId,
        studentId: studentId,
        score: 2,
        totalQuestions: 2,
        percentage: 100.0,
      );

      // Verify student's assignment updated to completed
      final updatedQuizzes = await dbHelper.getAssignedQuizzesForStudent(studentId, subjectId: subjectId);
      expect(updatedQuizzes.first['status'], equals('completed'));
      expect(updatedQuizzes.first['score'], equals(2));
      expect(updatedQuizzes.first['percentage'], equals(100.0));

      // 4. Verify automatic sync to quiz_attempts table
      final attempts = await db.query(
        'quiz_attempts',
        where: 'quiz_id = ? AND student_id = ?',
        whereArgs: [quizId, studentId],
      );
      expect(attempts, hasLength(1));
      expect(attempts.first['score'], equals(2));
      expect(attempts.first['is_passed'], equals(1));
      expect(attempts.first['percentage'], equals(100.0));

      // 5. Verify teacher roster reflects completed score
      final roster = await dbHelper.getQuizAssignmentRoster(quizId);
      expect(roster, hasLength(1));
      expect(roster.first['student_name'], equals('Student Loop Tester'));
      expect(roster.first['status'], equals('completed'));
      expect(roster.first['score'], equals(2));
      expect(roster.first['percentage'], equals(100.0));

      // 6. Verify teacher dashboard summary reflects live submissions
      final teacherDashboard = await dbHelper.getTeacherDashboardStats(teacherId);
      expect(teacherDashboard['totalAttempts'], greaterThanOrEqualTo(1));
      expect(teacherDashboard['passedAttempts'], greaterThanOrEqualTo(1));
      expect(teacherDashboard['passRate'], equals(100));

      final recentAttempts = teacherDashboard['recentAttempts'] as List<dynamic>;
      expect(recentAttempts.any((a) => a['student_id'] == studentId && a['quiz_id'] == quizId), isTrue);

      // 7. Verify admin analytics summary reflects the attempt
      final adminAnalytics = await dbHelper.getAdminAnalyticsSummary();
      expect(adminAnalytics['totalAttempts'], greaterThan(0));
      expect(adminAnalytics['passRate'], greaterThan(0));
    });

    test('2. Failing score sync correctly records is_passed = 0 in quiz_attempts and teacher dashboard', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_fail_$now';
      final studentId = 'student_fail_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'HashedPassword123',
        'role': 'teacher',
        'full_name': 'Prof Tough Grader',
        'section': 'Section Beta',
        'grade': 'Grade 11',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'HashedPassword123',
        'role': 'student',
        'full_name': 'Struggling Student',
        'section': 'Section Beta',
        'grade': 'Grade 11',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Physics $now',
        'subject_code': 'PHY-$now',
        'description': 'Advanced Physics',
        'teacher_id': teacherId,
        'teacher_name': 'Prof Tough Grader',
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await dbHelper.createQuiz(
        title: 'Quantum Mechanics Exam',
        subjectId: subjectId,
        teacherId: teacherId,
        teacherName: 'Prof Tough Grader',
        passingScore: 75,
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

      await dbHelper.assignQuizToStudents(quizId: quizId, studentIds: [studentId]);

      // Student scores 0 out of 2 (0%)
      await dbHelper.completeQuizAssignment(
        quizId: quizId,
        studentId: studentId,
        score: 0,
        totalQuestions: 2,
        percentage: 0.0,
      );

      // Verify quiz_attempts has is_passed = 0
      final attempts = await db.query(
        'quiz_attempts',
        where: 'quiz_id = ? AND student_id = ?',
        whereArgs: [quizId, studentId],
      );
      expect(attempts, hasLength(1));
      expect(attempts.first['score'], equals(0));
      expect(attempts.first['is_passed'], equals(0));
      expect(attempts.first['percentage'], equals(0.0));

      final teacherStats = await dbHelper.getTeacherDashboardStats(teacherId);
      expect(teacherStats['totalAttempts'], equals(1));
      expect(teacherStats['passedAttempts'], equals(0));
      expect(teacherStats['passRate'], equals(0));
    });

    test('3. Multi-student assignment tracks pending vs completed progress accurately', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 'teacher_multi_$now';
      final s1 = 'student_m1_$now';
      final s2 = 'student_m2_$now';
      final s3 = 'student_m3_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'HashedPassword123',
        'role': 'teacher',
        'full_name': 'Prof Multi Group',
        'created_at': DateTime.now().toIso8601String(),
      });

      for (final s in [s1, s2, s3]) {
        await db.insert('users', {
          'id': s,
          'email': '$s@school.edu',
          'username': s,
          'password': 'HashedPassword123',
          'role': 'student',
          'full_name': 'Student $s',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      final subjectId = await db.insert('subjects', {
        'name': 'History $now',
        'subject_code': 'HIS-$now',
        'description': 'History of WW2',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await dbHelper.createQuiz(
        title: 'World War 2 Quiz',
        subjectId: subjectId,
        teacherId: teacherId,
        passingScore: 70,
        questions: [
          {
            'question_text': 'Year WW2 ended?',
            'option_a': '1945',
            'option_b': '1939',
            'option_c': '1918',
            'option_d': '1950',
            'correct_option': 'A',
          },
        ],
      );

      final assignedCount = await dbHelper.assignQuizToStudents(
        quizId: quizId,
        studentIds: [s1, s2, s3],
      );
      expect(assignedCount, equals(3));

      // Initially 3 assigned, 0 completed
      var subjectQuizzes = await dbHelper.getQuizzesForSubject(subjectId);
      expect(subjectQuizzes.first['assigned_count'], equals(3));
      expect(subjectQuizzes.first['completed_count'], equals(0));

      // S1 completes the quiz
      await dbHelper.completeQuizAssignment(
        quizId: quizId,
        studentId: s1,
        score: 1,
        totalQuestions: 1,
        percentage: 100.0,
      );

      // Now 3 assigned, 1 completed
      subjectQuizzes = await dbHelper.getQuizzesForSubject(subjectId);
      expect(subjectQuizzes.first['assigned_count'], equals(3));
      expect(subjectQuizzes.first['completed_count'], equals(1));

      // Roster lists 3 students: S1 completed, S2 and S3 pending
      final roster = await dbHelper.getQuizAssignmentRoster(quizId);
      expect(roster, hasLength(3));
      expect(roster[0]['student_id'], equals(s1));
      expect(roster[0]['status'], equals('completed'));
      expect(roster.where((r) => r['status'] == 'pending').length, equals(2));
    });
  });
}
