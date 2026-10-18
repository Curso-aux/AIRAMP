import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/student/data/student_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? initialUser;
  MockAuthNotifier(this.initialUser);

  @override
  User? build() => initialUser;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Quiz Anti-Cheat & Timeout Enforcement Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. When student completes quiz, recordQuizAttempt enforces one-take and blocks duplicate attempts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 't_anticheat_$now';
      final studentId = 's_anticheat_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@school.edu',
        'username': teacherId,
        'password': 'Password123',
        'role': 'teacher',
        'full_name': 'Teacher Anticheat',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student Anticheat',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Science $now',
        'subject_code': 'SCI-$now',
        'description': 'Science Description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await db.insert('quizzes', {
        'title': 'Unit 1 Assessment',
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'passing_score': 70,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('quiz_assignments', {
        'quiz_id': quizId,
        'student_id': studentId,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      // Initially student can attempt
      final canAttemptInitial = await dbHelper.hasStudentCompletedQuiz(studentId: studentId, quizId: quizId);
      expect(canAttemptInitial, isTrue);

      // Student completes attempt (simulated timeout where isPassed = false)
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: 0,
        quizId: quizId,
        subjectId: subjectId,
        score: 1,
        totalQuestions: 2,
        percentage: 50.0,
        isPassed: false, // Timeout or failing grade
        durationSeconds: 120,
      );

      // Subsequent attempt check must return false
      final canAttemptAfter = await dbHelper.hasStudentCompletedQuiz(studentId: studentId, quizId: quizId);
      expect(canAttemptAfter, isFalse);

      // Attempting to record duplicate attempt throws an Exception
      expect(
        () async => await dbHelper.recordQuizAttempt(
          studentId: studentId,
          loId: 0,
          quizId: quizId,
          subjectId: subjectId,
          score: 2,
          totalQuestions: 2,
          percentage: 100.0,
          isPassed: true,
          durationSeconds: 60,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('2. LO quiz completion check hasStudentCompletedLoQuiz blocks duplicate LO attempts', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 's_lo_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student LO',
        'created_at': DateTime.now().toIso8601String(),
      });

      final loId = 999000 + (now % 1000);

      // Initially student has not completed LO quiz
      final canAttemptLo = await dbHelper.hasStudentCompletedLoQuiz(studentId: studentId, loId: loId);
      expect(canAttemptLo, isTrue);

      // Record LO attempt
      await dbHelper.recordQuizAttempt(
        studentId: studentId,
        loId: loId,
        quizId: null,
        subjectId: 1,
        score: 2,
        totalQuestions: 2,
        percentage: 100.0,
        isPassed: true,
        durationSeconds: 45,
      );

      // Now student cannot take LO quiz anymore
      final canAttemptLoAfter = await dbHelper.hasStudentCompletedLoQuiz(studentId: studentId, loId: loId);
      expect(canAttemptLoAfter, isFalse);
    });

    test('3. Student cannot self-reset quiz; resetQuizAttempt requires teacher or admin role', () async {
      final studentUser = User(
        id: 'student_123',
        email: 'student@school.edu',
        username: 'student123',
        role: 'student',
        fullName: 'Student Doe',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(studentUser)),
        ],
      );

      final notifier = container.read(studentQuizAttemptsProvider.notifier);

      // Student attempt to reset must throw Exception
      expect(
        () async => await notifier.resetQuizAttempt(quizId: 101),
        throwsA(predicate((e) => e.toString().contains('Only instructors or administrators are permitted'))),
      );
    });

    test('4. Teacher is authorized to invoke resetQuizAttempt in student repository', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherUser = User(
        id: 'teacher_123_$now',
        email: 'teacher@school.edu',
        username: 'teacher123',
        role: 'teacher',
        fullName: 'Teacher Doe',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(teacherUser)),
        ],
      );

      final notifier = container.read(studentQuizAttemptsProvider.notifier);

      // Teacher calling resetQuizAttempt should not throw authorization exception
      await expectLater(
        notifier.resetQuizAttempt(quizId: 999999),
        completes,
      );
    });

    test('5. markQuizAssignmentMissed updates status to missed and roster reflects Missed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 's_missed_$now';
      final teacherId = 't_missed_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student Missed',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Math $now',
        'subject_code': 'MATH-$now',
        'description': 'Math description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await db.insert('quizzes', {
        'title': 'Midterm Exam',
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'passing_score': 70,
        'schedule_end': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('quiz_assignments', {
        'quiz_id': quizId,
        'student_id': studentId,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      // Mark assignment as missed
      await dbHelper.markQuizAssignmentMissed(quizId: quizId, studentId: studentId);

      // Verify assignment status is 'missed'
      final assignments = await db.query(
        'quiz_assignments',
        where: 'quiz_id = ? AND student_id = ?',
        whereArgs: [quizId, studentId],
      );
      expect(assignments.first['status'], equals('missed'));

      // Verify roster reflects 'Missed'
      final roster = await dbHelper.getQuizAssignmentRoster(quizId);
      final studentRow = roster.firstWhere((r) => r['student_id'] == studentId);
      expect(studentRow['result'], equals('Missed'));
    });

    test('6. getAssignedQuizzesForStudent returns due_date and schedule dates correctly', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 's_schedule_$now';
      final teacherId = 't_schedule_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student Schedule',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'History $now',
        'subject_code': 'HIST-$now',
        'description': 'History Description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final dueDateStr = DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final schedStartStr = DateTime.now().add(const Duration(hours: 2)).toIso8601String();
      final schedEndStr = DateTime.now().add(const Duration(hours: 4)).toIso8601String();

      final quizId = await db.insert('quizzes', {
        'title': 'History Pop Quiz',
        'subject_id': subjectId,
        'teacher_id': teacherId,
        'due_date': dueDateStr,
        'schedule_start': schedStartStr,
        'schedule_end': schedEndStr,
        'passing_score': 75,
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.insert('quiz_assignments', {
        'quiz_id': quizId,
        'student_id': studentId,
        'assigned_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });

      final assignedQuizzes = await dbHelper.getAssignedQuizzesForStudent(studentId);
      final quizItem = assignedQuizzes.firstWhere((q) => q['quiz_id'] == quizId);

      expect(quizItem['due_date'], equals(dueDateStr));
      expect(quizItem['schedule_start'], equals(schedStartStr));
      expect(quizItem['schedule_end'], equals(schedEndStr));
    });

    test('7. Teacher editing quiz schedule applies new times to student view and reopens missed assignment', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 's_resched_$now';
      final teacherId = 't_resched_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'username': studentId,
        'password': 'Password123',
        'role': 'student',
        'full_name': 'Student Resched',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Science $now',
        'subject_code': 'SCI-$now',
        'description': 'Science Description',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Initially quiz was scheduled in the past
      final oldStart = DateTime.now().subtract(const Duration(hours: 3)).toIso8601String();
      final oldEnd = DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();

      final quizId = await dbHelper.createQuiz(
        title: 'Initial Science Quiz',
        subjectId: subjectId,
        teacherId: teacherId,
        scheduleStart: oldStart,
        scheduleEnd: oldEnd,
        dueDate: oldEnd,
        passingScore: 75,
        questions: [
          {
            'question_text': 'What is H2O?',
            'option_a': 'Water',
            'option_b': 'Air',
            'option_c': 'Gold',
            'option_d': 'Iron',
            'correct_option': 'A',
          },
        ],
      );

      // Student was assigned and missed it
      await dbHelper.assignQuizToStudents(
        quizId: quizId,
        studentIds: [studentId],
        dueDate: oldEnd,
      );
      await dbHelper.markQuizAssignmentMissed(quizId: quizId, studentId: studentId);

      var assigned = await dbHelper.getAssignedQuizzesForStudent(studentId);
      expect(assigned.firstWhere((q) => q['quiz_id'] == quizId)['status'], equals('missed'));

      // Now teacher edits the quiz with a brand new schedule window in the future
      final newStart = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
      final newEnd = DateTime.now().add(const Duration(hours: 2)).toIso8601String();

      await dbHelper.updateQuiz(
        quizId: quizId,
        title: 'Updated Science Quiz',
        subjectId: subjectId,
        timeLimitMinutes: 15,
        passingScore: 75,
        scheduleStart: newStart,
        scheduleEnd: newEnd,
        dueDate: newEnd,
        questions: [
          {
            'question_text': 'What is H2O?',
            'option_a': 'Water',
            'option_b': 'Air',
            'option_c': 'Gold',
            'option_d': 'Iron',
            'correct_option': 'A',
          },
        ],
      );

      await dbHelper.updateQuizAssignments(
        quizId: quizId,
        studentIds: [studentId],
        dueDate: newEnd,
      );

      // Student view should now reflect the updated times and pending status
      assigned = await dbHelper.getAssignedQuizzesForStudent(studentId);
      final updatedItem = assigned.firstWhere((q) => q['quiz_id'] == quizId);

      expect(updatedItem['title'], equals('Updated Science Quiz'));
      expect(updatedItem['schedule_start'], equals(newStart));
      expect(updatedItem['schedule_end'], equals(newEnd));
      expect(updatedItem['due_date'], equals(newEnd));
      expect(updatedItem['status'], equals('pending'));
    });
  });
}
