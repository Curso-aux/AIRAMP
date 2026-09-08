import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/quiz_parser.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Quiz System & Bulk Assignment Tests', () {
    test('1. Database v16 schema has quizzes and quiz_assignments tables', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('quizzes', 'quiz_assignments', 'questions', 'quiz_attempts')",
      );

      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames.contains('quizzes'), isTrue);
      expect(tableNames.contains('quiz_assignments'), isTrue);
      expect(tableNames.contains('questions'), isTrue);
      expect(tableNames.contains('quiz_attempts'), isTrue);

      // Verify quiz_id column in questions
      final qColumns = await db.rawQuery('PRAGMA table_info(questions)');
      expect(qColumns.any((c) => c['name'] == 'quiz_id'), isTrue);

      // Verify quiz_id column in quiz_attempts
      final qaColumns = await db.rawQuery('PRAGMA table_info(quiz_attempts)');
      expect(qaColumns.any((c) => c['name'] == 'quiz_id'), isTrue);
    });

    test('2. QuizParser parses bulk formatted text and JSON', () {
      const textInput = '''1. What is Flutter?
A) An open-source UI software development kit
B) A web browser
C) A database engine
D) A programming language
Answer: A

2. Which keyword is used to declare a constant in Dart?
A) var
B) const
C) let
D) final
Answer: B''';

      final result = QuizParser.parse(textInput);
      expect(result.hasErrors, isFalse);
      expect(result.questions.length, equals(2));
      expect(result.questions[0].questionText, equals('What is Flutter?'));
      expect(result.questions[0].optionA, equals('An open-source UI software development kit'));
      expect(result.questions[0].correctOption, equals('A'));
      expect(result.questions[1].questionText, equals('Which keyword is used to declare a constant in Dart?'));
      expect(result.questions[1].optionB, equals('const'));
      expect(result.questions[1].correctOption, equals('B'));

      // Test JSON format
      const jsonInput = '''[
        {
          "question": "What is Dart?",
          "option_a": "Client-optimized language",
          "option_b": "Operating system",
          "option_c": "Cloud provider",
          "option_d": "Web server",
          "correct_option": "A"
        }
      ]''';

      final jsonResult = QuizParser.parse(jsonInput);
      expect(jsonResult.hasErrors, isFalse);
      expect(jsonResult.questions.length, equals(1));
      expect(jsonResult.questions[0].questionText, equals('What is Dart?'));
      expect(jsonResult.questions[0].correctOption, equals('A'));
    });

    test('3. Teacher quiz creation and bulk student assignment ("Select All")', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Seed 3 test students
      final testStudents = [
        {'id': 'bulk_student_1', 'email': 'b1@test.com', 'name': 'Bulk Student One', 'section': 'Emerald'},
        {'id': 'bulk_student_2', 'email': 'b2@test.com', 'name': 'Bulk Student Two', 'section': 'Emerald'},
        {'id': 'bulk_student_3', 'email': 'b3@test.com', 'name': 'Bulk Student Three', 'section': 'Ruby'},
      ];

      for (final s in testStudents) {
        await db.insert('users', {
          'id': s['id'],
          'email': s['email'],
          'password': 'Password123',
          'role': 'student',
          'full_name': s['name'],
          'section': s['section'],
          'grade': 'Grade 10',
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      final subjects = await db.query('subjects');
      final subjectId = subjects.isNotEmpty ? subjects.first['id'] as int : 1;

      // 1. Create Quiz
      final quizId = await helper.createQuiz(
        title: 'Diagnostic Quiz Sprint 1',
        description: 'Comprehensive Sprint 1 Knowledge Check',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        teacherName: 'Sir John Reyes',
        timeLimitMinutes: 15,
        passingScore: 70,
        questions: [
          {
            'question_text': 'What is State in Flutter?',
            'option_a': 'Information that can be read synchronously when the widget is built',
            'option_b': 'A database file',
            'option_c': 'Network packet',
            'option_d': 'CPU cycle',
            'correct_option': 'A',
          },
          {
            'question_text': 'Which widget is immutable?',
            'option_a': 'StatelessWidget',
            'option_b': 'StatefulWidget',
            'option_c': 'MutableWidget',
            'option_d': 'DynamicWidget',
            'correct_option': 'A',
          },
        ],
      );

      expect(quizId, greaterThan(0));

      // 2. Bulk Assign to all 3 students ("Select All" behavior)
      final allStudentIds = testStudents.map((s) => s['id']!).toList();
      final assignedCount = await helper.assignQuizToStudents(
        quizId: quizId,
        studentIds: allStudentIds,
        dueDate: DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      );

      expect(assignedCount, equals(3));

      // 3. Verify Teacher subject quizzes summary
      final quizzes = await helper.getQuizzesForSubject(subjectId);
      final createdQuiz = quizzes.firstWhere((q) => q['id'] == quizId);
      expect(createdQuiz['assigned_count'], equals(3));
      expect(createdQuiz['completed_count'], equals(0));
      expect(createdQuiz['question_count'], equals(2));

      // 4. Verify Student perspective - Assigned Quizzes
      final student1Assigned = await helper.getAssignedQuizzesForStudent('bulk_student_1');
      expect(student1Assigned.any((a) => a['quiz_id'] == quizId), isTrue);
      final student1Quiz = student1Assigned.firstWhere((a) => a['quiz_id'] == quizId);
      expect(student1Quiz['status'], equals('pending'));
      expect(student1Quiz['title'], equals('Diagnostic Quiz Sprint 1'));
      expect(student1Quiz['time_limit_minutes'], equals(15));
      expect(student1Quiz['passing_score'], equals(70));

      // 5. Student takes and completes quiz
      await helper.recordQuizAttempt(
        studentId: 'bulk_student_1',
        loId: 0,
        quizId: quizId,
        subjectId: subjectId,
        score: 2,
        totalQuestions: 2,
        percentage: 100.0,
        isPassed: true,
        durationSeconds: 180,
      );

      // Verify assignment status transitioned to 'completed'
      final student1AssignedAfter = await helper.getAssignedQuizzesForStudent('bulk_student_1');
      final completedQuiz = student1AssignedAfter.firstWhere((a) => a['quiz_id'] == quizId);
      expect(completedQuiz['status'], equals('completed'));
      expect(completedQuiz['score'], equals(2));
      expect(completedQuiz['percentage'], equals(100.0));

      // 6. Teacher Roster verification
      final roster = await helper.getQuizAssignmentRoster(quizId);
      expect(roster.length, equals(3));
      final student1RosterRow = roster.firstWhere((r) => r['student_id'] == 'bulk_student_1');
      expect(student1RosterRow['status'], equals('completed'));
      expect(student1RosterRow['score'], equals(2));

      final pendingStudents = roster.where((r) => r['status'] == 'pending');
      expect(pendingStudents.length, equals(2));

      // 7. Teacher Live Scores query includes this submission
      final allScores = await helper.getAllQuizScores();
      expect(allScores.any((s) => s['student_id'] == 'bulk_student_1' && s['quiz_id'] == quizId), isTrue);
    });

    test('4. getStudentsForSubjectOrAll returns enrolled or all fallback students without locking', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Clean enrollments for subject 999
      await db.delete('enrollments', where: 'subject_id = ?', whereArgs: [999]);

      // Should fallback to all registered test students so assignment is never blocked
      final fallbackStudents = await helper.getStudentsForSubjectOrAll(999);
      expect(fallbackStudents.length, greaterThanOrEqualTo(3));

      // Now enroll only student 1 in subject 999
      await db.insert('enrollments', {
        'student_id': 'bulk_student_1',
        'subject_id': 999,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final enrolledOnly = await helper.getStudentsForSubjectOrAll(999);
      expect(enrolledOnly.length, equals(1));
      expect(enrolledOnly.first['id'], equals('bulk_student_1'));
    });
  });
}
