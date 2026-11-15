import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/quiz_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LO Quiz ID Collision & Empty Questions State Logic Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. hasStudentCompletedQuiz does not conflate quiz_id with lo_id', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_test_$now';
      final db = await dbHelper.database;

      final subjectId = await db.insert('subjects', {
        'name': 'Logic Subject $now',
        'subject_code': 'LOG-$now',
        'description': 'Logic Subject Description',
        'created_at': DateTime.now().toIso8601String(),
      });

      final topicId = await db.insert('topics', {
        'subject_id': subjectId,
        'title': 'Logic Topic',
        'created_at': DateTime.now().toIso8601String(),
      });

      // LO with an ID (e.g. 999)
      final loId = await db.insert('learning_outcomes', {
        'topic_id': topicId,
        'title': 'Logic LO',
        'passing_score': 70,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert attempt for STANDALONE quiz whose quiz_id matches loId!
      await db.insert('quiz_attempts', {
        'student_id': studentId,
        'lo_id': null,
        'quiz_id': loId, // matching number, but is a quiz_id!
        'subject_id': subjectId,
        'score': 10,
        'total_questions': 10,
        'percentage': 100.0,
        'is_passed': 1,
        'attempted_at': DateTime.now().toIso8601String(),
      });

      // 1. For standalone quiz, hasStudentCompletedQuiz returns FALSE (already taken)
      final canAttemptStandalone = await dbHelper.hasStudentCompletedQuiz(
        studentId: studentId,
        quizId: loId,
      );
      expect(canAttemptStandalone, isFalse);

      // 2. For the LO quiz with the SAME ID, hasStudentCompletedLoQuiz returns TRUE (NOT taken!)
      final canAttemptLo = await dbHelper.hasStudentCompletedLoQuiz(
        studentId: studentId,
        loId: loId,
      );
      expect(canAttemptLo, isTrue);

      // 3. getLoQuiz returns questions: []
      final loQuiz = await dbHelper.getLoQuiz(loId);
      expect(loQuiz, isNotNull);
      expect((loQuiz!['questions'] as List).isEmpty, isTrue);
    });

    testWidgets('2. QuizScreen renders "No Assessment Questions" when quiz has 0 questions', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: QuizScreen(quizId: '9999999'),
            ),
          ),
        );
        // Wait for async DatabaseHelper calls to complete
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();

      expect(find.text('No Assessment Questions'), findsOneWidget);
      expect(find.textContaining('The instructor has not added quiz questions'), findsOneWidget);
      expect(find.text('Quiz Already Completed'), findsNothing);
    });
  });
}
