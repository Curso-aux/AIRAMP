import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/quiz_view_dialog.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/create_quiz_dialog.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Teacher Quiz View & Status Selection Tests', () {
    testWidgets('1. QuizViewDialog renders quiz metadata, questions, and highlighted correct answer', (tester) async {
      final sampleQuizData = {
        'id': 42,
        'title': 'State Management Quiz',
        'description': 'Test your Riverpod and state management knowledge',
        'subject_id': 101,
        'time_limit_minutes': 20,
        'passing_score': 75,
        'status': 'published',
        'due_date': '2026-10-01T00:00:00.000',
        'questions': [
          {
            'id': 1,
            'question_text': 'What is Riverpod?',
            'option_a': 'A reactive caching and state-management framework',
            'option_b': 'A database engine',
            'option_c': 'A web server',
            'option_d': 'A CSS framework',
            'correct_option': 'A',
          },
          {
            'id': 2,
            'question_text': 'Which provider is best for async data?',
            'option_a': 'FutureProvider',
            'option_b': 'RawProvider',
            'option_c': 'StaticProvider',
            'option_d': 'None',
            'correct_option': 'A',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: QuizViewDialog(
              quizId: 42,
              quizTitle: 'State Management Quiz',
              subjectId: 101,
              subjectName: 'Mobile UI',
              initialQuizData: sampleQuizData,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and metadata
      expect(find.text('Quiz Overview & Questions'), findsOneWidget);
      expect(find.text('State Management Quiz'), findsWidgets);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('2 Questions'), findsOneWidget);
      expect(find.text('Pass: 75%'), findsOneWidget);
      expect(find.text('20 Mins'), findsOneWidget);

      // Verify question content & options
      expect(find.text('What is Riverpod?'), findsOneWidget);
      expect(find.text('A reactive caching and state-management framework'), findsOneWidget);
      expect(find.text('A database engine'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Which provider is best for async data?'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Preview as Student'), findsOneWidget);
      expect(find.text('Edit Quiz'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('2. CreateQuizDialog renders Quiz Status as a clean Dropdown with Published and Draft', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const CreateQuizDialog(
              subjectId: 1,
              subjectName: 'Subject Test',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Quiz Status label
      expect(find.text('Quiz Status'), findsOneWidget);

      // Verify Dropdown with Published option selected
      expect(find.textContaining('Published — Active for assigned students'), findsOneWidget);
    });

    test('3. DatabaseHelper getQuizById loads full quiz questions and options for teacher viewing', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 't_db_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@test.edu',
        'username': teacherId,
        'password': 'Password123',
        'role': 'teacher',
        'full_name': 'Teacher DB',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'DB Subject $now',
        'subject_code': 'DBS-$now',
        'description': 'Subject for DB Quiz View test',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await dbHelper.createQuiz(
        title: 'DB Quiz $now',
        description: 'Testing DB quiz loading',
        subjectId: subjectId,
        teacherId: teacherId,
        timeLimitMinutes: 15,
        passingScore: 70,
        status: 'published',
        questions: [
          {
            'question_text': 'What does SQL stand for?',
            'option_a': 'Structured Query Language',
            'option_b': 'Simple Quick Logic',
            'option_c': 'Standard Question Language',
            'option_d': 'Server Query Layout',
            'correct_option': 'A',
          },
        ],
      );

      final loadedQuiz = await dbHelper.getQuizById(quizId);
      expect(loadedQuiz, isNotNull);
      expect(loadedQuiz!['title'], equals('DB Quiz $now'));
      expect(loadedQuiz['time_limit_minutes'], equals(15));
      expect(loadedQuiz['passing_score'], equals(70));
      expect(loadedQuiz['status'], equals('published'));

      final questions = (loadedQuiz['questions'] as List).cast<Map<String, dynamic>>();
      expect(questions, hasLength(1));
      expect(questions.first['question_text'], equals('What does SQL stand for?'));
      expect(questions.first['correct_option'], equals('A'));
    });

    testWidgets('4. CreateQuizDialog locks Passing Score to 75% and displays 2 SET TIME controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const CreateQuizDialog(
              subjectId: 1,
              subjectName: 'Subject Test',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify passing score is locked at 75% (teacher cannot change it)
      expect(find.text('75% (Fixed Standard)'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);

      // Verify 2 Set Time controls
      expect(find.text('1. Quiz Start (Date & Time)'), findsOneWidget);
      expect(find.text('2. Quiz End (Date & Time)'), findsOneWidget);
      expect(find.text('Quiz Schedule (Start & End Time)'), findsOneWidget);
    });

    test('5. DatabaseHelper updateQuiz successfully saves and updates updated_at without SQLite error', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;
      final teacherId = 't_upd_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': teacherId,
        'email': '$teacherId@test.edu',
        'username': teacherId,
        'password': 'Password123',
        'role': 'teacher',
        'full_name': 'Teacher Update',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Subject Upd $now',
        'subject_code': 'UPD-$now',
        'description': 'Subject for update test',
        'teacher_id': teacherId,
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await dbHelper.createQuiz(
        title: 'Initial Quiz $now',
        description: 'Initial description',
        subjectId: subjectId,
        teacherId: teacherId,
        timeLimitMinutes: 15,
        passingScore: 75,
        status: 'published',
        questions: [
          {
            'question_text': 'Question 1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'A',
          },
        ],
      );

      // Perform updateQuiz with updated schedule start and end
      final startIso = DateTime.now().add(const Duration(hours: 1)).toIso8601String();
      final endIso = DateTime.now().add(const Duration(hours: 2)).toIso8601String();

      await dbHelper.updateQuiz(
        quizId: quizId,
        title: 'Updated Quiz $now',
        description: 'Updated description',
        subjectId: subjectId,
        timeLimitMinutes: 20,
        passingScore: 75,
        status: 'published',
        dueDate: endIso,
        scheduleStart: startIso,
        scheduleEnd: endIso,
        questions: [
          {
            'question_text': 'Updated Question 1',
            'option_a': 'A1',
            'option_b': 'B1',
            'option_c': 'C1',
            'option_d': 'D1',
            'correct_option': 'B',
          },
        ],
      );

      final updated = await dbHelper.getQuizById(quizId);
      expect(updated, isNotNull);
      expect(updated!['title'], equals('Updated Quiz $now'));
      expect(updated['passing_score'], equals(75));
      expect(updated['time_limit_minutes'], equals(20));
      expect(updated['schedule_start'], equals(startIso));
      expect(updated['schedule_end'], equals(endIso));
      expect(updated['due_date'], equals(endIso));
    });
  });
}
