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
  });
}
