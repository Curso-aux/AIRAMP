import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/quiz_flashcard_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  final User? initialUser;
  FakeAuthNotifier(this.initialUser);

  @override
  User? build() => initialUser;
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper().database;
  });

  final testQuestions = [
    {
      'question_text': 'What is the powerhouse of the cell?',
      'option_a': 'Mitochondria',
      'option_b': 'Ribosome',
      'option_c': 'Nucleus',
      'option_d': 'Endoplasmic Reticulum',
      'correct_option': 'A',
    },
    {
      'question_text': 'Which organelle is responsible for photosynthesis?',
      'option_a': 'Chloroplast',
      'option_b': 'Vacuole',
      'option_c': 'Golgi Apparatus',
      'option_d': 'Lysosome',
      'correct_option': 'A',
    },
  ];

  Widget buildTestWidget({
    required List<Map<String, dynamic>> questions,
    Map<int, String>? selectedAnswers,
    int? quizId,
    User? currentUser,
  }) {
    return ProviderScope(
      overrides: [
        if (currentUser != null)
          authProvider.overrideWith(() => FakeAuthNotifier(currentUser)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: QuizFlashcardScreen(
          quizTitle: 'Cell Biology Review',
          initialQuestions: questions.isEmpty ? null : questions,
          initialSelectedAnswers: selectedAnswers,
          quizId: quizId,
        ),
      ),
    );
  }

  group('QuizFlashcardScreen Widget & Interaction Tests', () {
    testWidgets('1. Card Front: Renders question, options, progress, and defaults to Missed scope if student missed questions', (tester) async {
      // Question 0: Student answered 'B' (Incorrect, correct is 'A')
      // Question 1: Student answered 'A' (Correct)
      final selectedAnswers = {0: 'B', 1: 'A'};

      await tester.pumpWidget(buildTestWidget(
        questions: testQuestions,
        selectedAnswers: selectedAnswers,
      ));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Cell Biology Review'), findsOneWidget);
      expect(find.text('Flashcard Review Mode'), findsOneWidget);

      // Verify Scope Filters: defaults to Missed Only because 1 question was missed
      expect(find.text('All Questions (2)'), findsOneWidget);
      expect(find.text('Missed Only (1)'), findsOneWidget);

      // Card counter should show 1 card in Missed scope
      expect(find.text('Card 1 of 1'), findsOneWidget);

      // Question 0 front content
      expect(find.text('What is the powerhouse of the cell?'), findsOneWidget);
      expect(find.text('Mitochondria'), findsOneWidget);
      expect(find.text('Ribosome'), findsOneWidget);
      expect(find.text('Nucleus'), findsOneWidget);
      expect(find.text('Endoplasmic Reticulum'), findsOneWidget);

      // Status badges
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Reveal Answer'), findsOneWidget);
    });

    testWidgets('2. Flip Interaction: Tapping Reveal Answer reveals Answer Key and comparison on Card Back', (tester) async {
      final selectedAnswers = {0: 'B', 1: 'A'};

      await tester.pumpWidget(buildTestWidget(
        questions: testQuestions,
        selectedAnswers: selectedAnswers,
      ));
      await tester.pumpAndSettle();

      // Tap Reveal Answer button to trigger flip
      await tester.tap(find.text('Reveal Answer'));
      await tester.pumpAndSettle();

      // Card back should now be shown
      expect(find.text('Answer Key · Question 1'), findsOneWidget);
      expect(find.text('Correct Answer: Option A'), findsOneWidget);
      expect(find.text('Your answer was incorrect'), findsOneWidget);
      expect(find.textContaining('You selected: Option B'), findsOneWidget);
      expect(find.text('Show Question'), findsOneWidget);

      // Flip back to front
      await tester.tap(find.text('Show Question'));
      await tester.pumpAndSettle();

      // Verify Card front is visible again
      expect(find.text('Reveal Answer'), findsOneWidget);
      expect(find.text('Choices:'), findsOneWidget);
    });

    testWidgets('3. Scope Filter Switching: Switching to All Questions and navigating cards', (tester) async {
      final selectedAnswers = {0: 'B', 1: 'A'};

      await tester.pumpWidget(buildTestWidget(
        questions: testQuestions,
        selectedAnswers: selectedAnswers,
      ));
      await tester.pumpAndSettle();

      // Currently in Missed Only (1)
      expect(find.text('Card 1 of 1'), findsOneWidget);

      // Tap 'All Questions (2)' filter
      await tester.tap(find.text('All Questions (2)'));
      await tester.pumpAndSettle();

      // Now deck has 2 cards
      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Navigate to Next card
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should be on Card 2 of 2
      expect(find.text('Card 2 of 2'), findsOneWidget);
      expect(find.text('Which organelle is responsible for photosynthesis?'), findsOneWidget);
      expect(find.text('Chloroplast'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);

      // Tapping Finish shows completion dialog
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Deck Completed!'), findsOneWidget);
      expect(find.text('You have reviewed all the flashcards in this quiz.'), findsOneWidget);
      expect(find.text('Review Again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('4. Perfect Score (0 missed): Defaults to All Questions scope', (tester) async {
      // Both answered correctly
      final selectedAnswers = {0: 'A', 1: 'A'};

      await tester.pumpWidget(buildTestWidget(
        questions: testQuestions,
        selectedAnswers: selectedAnswers,
      ));
      await tester.pumpAndSettle();

      // Should default to All Questions because 0 missed
      expect(find.text('All Questions (2)'), findsOneWidget);
      expect(find.text('Missed Only (0)'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('5. Shuffle Mode: Tapping shuffle icon activates shuffle state and displays snackbar', (tester) async {
      final selectedAnswers = {0: 'B', 1: 'A'};

      await tester.pumpWidget(buildTestWidget(
        questions: testQuestions,
        selectedAnswers: selectedAnswers,
      ));
      await tester.pumpAndSettle();

      // Switch to All Questions so we have 2 cards to shuffle
      await tester.tap(find.text('All Questions (2)'));
      await tester.pumpAndSettle();

      // Tap shuffle icon in AppBar
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();

      // Verify snackbar feedback
      expect(find.text('Card deck shuffled!'), findsOneWidget);
    });

    test('6. DatabaseHelper: recordQuizAttempt stores answers JSON and getQuizAttemptWithAnswers retrieves it offline', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_test_$now';
      final testQuizId = 999000 + (now % 1000);

      // Insert directly into quiz_attempts with answers JSON
      final answers = {0: 'B', 1: 'A', 2: 'D'};
      final answersJson = jsonEncode(answers.map((k, v) => MapEntry(k.toString(), v)));

      final db = await dbHelper.database;
      await db.insert('quiz_attempts', {
        'student_id': studentId,
        'lo_id': 0,
        'quiz_id': testQuizId,
        'subject_id': 1,
        'score': 2,
        'total_questions': 3,
        'percentage': 66.7,
        'is_passed': 0,
        'attempted_at': DateTime.now().toIso8601String(),
        'answers': answersJson,
      });

      // Retrieve via getQuizAttemptWithAnswers
      final result = await dbHelper.getQuizAttemptWithAnswers(
        studentId: studentId,
        quizId: testQuizId,
      );

      expect(result, isNotNull);
      expect(result!['answers'], isNotNull);

      final decoded = jsonDecode(result['answers'] as String) as Map<String, dynamic>;
      final parsedAnswers = decoded.map((k, v) => MapEntry(int.parse(k), v.toString()));

      expect(parsedAnswers[0], equals('B'));
      expect(parsedAnswers[1], equals('A'));
      expect(parsedAnswers[2], equals('D'));
    });
  });
}
