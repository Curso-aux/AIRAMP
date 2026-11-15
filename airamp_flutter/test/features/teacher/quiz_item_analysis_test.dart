import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/quiz_item_analysis_dialog.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/domain/item_analysis_model.dart';

void main() {
  final sampleReport = ItemAnalysisReport(
    quizId: 2,
    quizTitle: 'Flutter & Dart Assessment',
    subjectName: 'Computer Programming',
    subjectCode: 'CP101',
    totalQuestions: 2,
    totalAttempts: 1,
    passingScore: 70.0,
    meanScore: 100.0,
    medianScore: 100.0,
    passRate: 100.0,
    kr20Reliability: null,
    reliabilityRating: 'N/A',
    meanDifficulty: 1.0,
    meanDiscrimination: 0.0,
    retainCount: 2,
    reviseCount: 0,
    discardCount: 0,
    checkKeyCount: 0,
    questions: const [
      QuestionItemAnalysis(
        index: 1,
        questionId: 10,
        questionText: 'What is Flutter?',
        correctOption: 'A',
        optionTexts: {'A': 'UI toolkit', 'B': 'Database', 'C': 'Server', 'D': 'IDE'},
        totalSelections: {'A': 1, 'B': 0, 'C': 0, 'D': 0},
        selectionPercentages: {'A': 100.0, 'B': 0.0, 'C': 0.0, 'D': 0.0},
        upperGroupSelections: {'A': 1, 'B': 0, 'C': 0, 'D': 0},
        lowerGroupSelections: {'A': 1, 'B': 0, 'C': 0, 'D': 0},
        skippedCount: 0,
        totalRespondents: 1,
        difficultyIndex: 1.0,
        difficultyLabel: 'Very Easy',
        discriminationIndex: 0.0,
        discriminationLabel: 'Poor',
        recommendation: ItemAction.retain,
        recommendationLabel: 'Retain Item',
        distractorWarnings: [],
        pedagogicalAdvice: 'High-performing item.',
      ),
    ],
  );

  final sampleReportZeroAttempts = ItemAnalysisReport.empty(
    quizId: 3,
    quizTitle: 'Unattempted Quiz',
  );

  group('QuizItemAnalysisDialog & Psychometrics Robustness', () {
    testWidgets('1. Does not crash when first quiz in list is filtered out (safe DropdownButton value)', (tester) async {
      final quizzes = [
        {
          'id': 1,
          'title': 'Diagnostic Quiz Sprint',
          'subject_name': 'Science',
          'subject_code': 'SCI',
          'question_count': 5,
          'attempt_count': 0,
        },
        {
          'id': 2,
          'title': 'Flutter & Dart Assessment',
          'subject_name': 'Programming',
          'subject_code': 'PROG',
          'question_count': 2,
          'attempt_count': 1,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherQuizzesForAnalysisProvider(null).overrideWith((ref) async => quizzes),
            quizItemAnalysisProvider(1).overrideWith((ref) async => sampleReport),
            quizItemAnalysisProvider(2).overrideWith((ref) async => sampleReport),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuizItemAnalysisDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('Quiz Item Analysis'), findsOneWidget);
      expect(find.text('Flutter & Dart Assessment (1 students · 2 questions)'), findsOneWidget);
    });

    testWidgets('2. Gracefully renders empty state when quiz list is completely empty or filtered out', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherQuizzesForAnalysisProvider(null).overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuizItemAnalysisDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('No quizzes available for analysis yet.'), findsOneWidget);
    });

    testWidgets('3. Renders single-attempt quiz and small sample warning cleanly without overflow', (tester) async {
      final quizzes = [
        {
          'id': 2,
          'title': 'Flutter & Dart Assessment',
          'subject_name': 'Programming',
          'subject_code': 'PROG',
          'question_count': 2,
          'attempt_count': 1,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherQuizzesForAnalysisProvider(null).overrideWith((ref) async => quizzes),
            quizItemAnalysisProvider(2).overrideWith((ref) async => sampleReport),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuizItemAnalysisDialog(initialQuizId: 2),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Initial Assessment Phase (1 submission)'), findsOneWidget);
      expect(find.text('100.0 pts'), findsOneWidget);
      expect(find.text('Pass Rate: 100%'), findsOneWidget);
    });

    testWidgets('4. Handles zero attempts quiz state with actionable refresh and delete controls', (tester) async {
      final quizzes = [
        {
          'id': 3,
          'title': 'Unattempted Quiz',
          'subject_name': 'Programming',
          'subject_code': 'PROG',
          'question_count': 5,
          'attempt_count': 0,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherQuizzesForAnalysisProvider(null).overrideWith((ref) async => quizzes),
            quizItemAnalysisProvider(3).overrideWith((ref) async => sampleReportZeroAttempts),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuizItemAnalysisDialog(initialQuizId: 3),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text('No Student Submissions Yet'), findsOneWidget);
      expect(find.text('Refresh Submissions'), findsOneWidget);
    });

    testWidgets('5. Toggling "With submissions only" adjusts selection without crashing', (tester) async {
      final quizzes = [
        {
          'id': 10,
          'title': 'Draft Quiz Without Submissions',
          'subject_name': 'Math',
          'subject_code': 'M101',
          'question_count': 5,
          'attempt_count': 0,
        },
        {
          'id': 20,
          'title': 'Final Exam with Submissions',
          'subject_name': 'Math',
          'subject_code': 'M101',
          'question_count': 10,
          'attempt_count': 15,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherQuizzesForAnalysisProvider(null).overrideWith((ref) async => quizzes),
            quizItemAnalysisProvider(10).overrideWith((ref) async => sampleReportZeroAttempts),
            quizItemAnalysisProvider(20).overrideWith((ref) async => sampleReport),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuizItemAnalysisDialog(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap "With submissions only" filter
      final filterToggle = find.text('With submissions only');
      expect(filterToggle, findsOneWidget);
      await tester.tap(filterToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
    });
  });
}
