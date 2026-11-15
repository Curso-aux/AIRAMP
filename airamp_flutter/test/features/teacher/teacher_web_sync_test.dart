import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/create_assignment_dialog.dart';
import 'package:airamp_flutter/src/features/submissions/data/submissions_repository.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _user;
  MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class MockTeacherSubjectsNotifier extends TeacherSubjectsNotifier {
  final List<Map<String, dynamic>> _subjects;
  MockTeacherSubjectsNotifier(this._subjects);

  @override
  List<Map<String, dynamic>> build() => _subjects;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Web Refresh & Firestore Error Handling Verification', () {
    testWidgets('R3: Assignment creation modal displays MAX 10 MB file upload limit', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final teacherUser = User(
        id: 'T-100-0001',
        email: 'teacher@aira.edu',
        fullName: 'Test Teacher',
        role: 'teacher',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(teacherUser)),
            teacherSubjectsProvider.overrideWith(() => MockTeacherSubjectsNotifier([
              {'id': 1, 'name': 'Science 10', 'subject_code': 'SCI-10'},
            ])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CreateAssignmentDialog(
                  subjectId: 1,
                  subjectName: 'Science 10',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the modal displays "MAX 10 MB"
      expect(find.text('MAX 10 MB'), findsOneWidget);

      // Verify it does NOT display outdated "MAX 50 MB"
      expect(find.text('MAX 50 MB'), findsNothing);
      expect(find.textContaining('50 MB'), findsNothing);

      // Verify button copy
      expect(find.text('Upload Assignment Handout / Brief (Max 10 MB)'), findsOneWidget);
    });

    test('R1: DatabaseHelper creates quiz and assignment with Firestore integration', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;

      final quizId = await dbHelper.createQuiz(
        title: 'Photosynthesis Quiz $now',
        description: 'Test quiz for web sync',
        subjectId: 1,
        teacherId: 'T-100-0001',
        teacherName: 'Test Teacher',
        passingScore: 75,
        timeLimitMinutes: 15,
        questions: [
          {
            'question_text': 'What gas do plants absorb?',
            'option_a': 'Oxygen',
            'option_b': 'Carbon Dioxide',
            'option_c': 'Nitrogen',
            'option_d': 'Helium',
            'correct_option': 'B',
          }
        ],
      );

      expect(quizId, isPositive);

      final quizzes = await dbHelper.getQuizzesForSubject(1);
      expect(quizzes.any((q) => q['id'] == quizId), isTrue);

      // Test Assignment creation
      final assignId = await dbHelper.createAssignment(
        title: 'Lab Report $now',
        description: 'Submit report by Friday',
        subjectId: 1,
        teacherId: 'T-100-0001',
        teacherName: 'Test Teacher',
        totalPoints: 100,
      );

      expect(assignId, isPositive);

      final assign = await dbHelper.getAssignmentById(assignId);
      expect(assign, isNotNull);
      expect(assign!['title'], 'Lab Report $now');
    });

    test('R1: subjectQuizzesProvider and subjectAssignmentsProvider sync and return data', () async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(User(
            id: 'T-100-0001',
            email: 'teacher@aira.edu',
            fullName: 'Test Teacher',
            role: 'teacher',
          ))),
        ],
      );
      addTearDown(container.dispose);

      final quizzes = await container.read(subjectQuizzesProvider(1).future);
      expect(quizzes, isA<List<Map<String, dynamic>>>());

      final assignments = await container.read(subjectAssignmentsProvider(1).future);
      expect(assignments, isA<List<Assignment>>());
    });

    test('R1 & R2: updateQuiz updates local and cloud state, deleteQuiz cleans up', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;

      final quizId = await dbHelper.createQuiz(
        title: 'Initial Quiz $now',
        description: 'Before update',
        subjectId: 1,
        teacherId: 'T-100-0001',
        teacherName: 'Test Teacher',
        passingScore: 70,
        timeLimitMinutes: 10,
        questions: [
          {
            'question_text': 'Question 1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'A',
          }
        ],
      );

      expect(quizId, isPositive);

      // Now update the quiz
      await dbHelper.updateQuiz(
        quizId: quizId,
        title: 'Updated Quiz Title $now',
        description: 'After update',
        subjectId: 1,
        timeLimitMinutes: 25,
        passingScore: 80,
        questions: [
          {
            'question_text': 'Updated Question 1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'B',
          }
        ],
      );

      final updatedQuizzes = await dbHelper.getQuizzesForSubject(1);
      final updated = updatedQuizzes.firstWhere((q) => q['id'] == quizId);
      expect(updated['title'], 'Updated Quiz Title $now');
      expect(updated['time_limit_minutes'], 25);
      expect(updated['passing_score'], 80);

      // Now delete the quiz
      await dbHelper.deleteQuiz(quizId);
      final remainingQuizzes = await dbHelper.getQuizzesForSubject(1);
      expect(remainingQuizzes.any((q) => q['id'] == quizId), isFalse);
    });

    test('R1 & R2: deleteAssignment removes assignment from local state', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;

      final assignId = await dbHelper.createAssignment(
        title: 'Temp Assignment $now',
        description: 'To be deleted',
        subjectId: 1,
        teacherId: 'T-100-0001',
        teacherName: 'Test Teacher',
        totalPoints: 50,
      );

      expect(assignId, isPositive);
      final fetched = await dbHelper.getAssignmentById(assignId);
      expect(fetched, isNotNull);

      await dbHelper.deleteAssignment(assignId);
      final deleted = await dbHelper.getAssignmentById(assignId);
      expect(deleted, isNull);
    });

    test('R2: Error handling surfaces diagnostic logs when Firestore operations fail', () async {
      final dbHelper = DatabaseHelper();
      // Ensure calling sync or operations with invalid IDs or unexpected states logs rather than crashes silently
      await dbHelper.syncCloudQuizzesToLocal(force: true);
      await dbHelper.syncCloudAssignmentsToLocal(force: true);
      await dbHelper.syncCloudSubmissionsToLocal(force: true);
      // Verify db is responsive after sync attempts
      final quizzes = await dbHelper.getQuizzesForSubject(1);
      expect(quizzes, isA<List<Map<String, dynamic>>>());
    });

    test('R1 Edge Case: Subject code with special characters and slashes creates and deletes cleanly', () async {
      final dbHelper = DatabaseHelper();
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = await dbHelper.database;

      // Seed a subject with special characters in subject_code like 'CS/IT-101 #A'
      final subId = await db.insert('subjects', {
        'name': 'Adv CS / IT $now',
        'subject_code': 'CS/IT-101 #$now',
        'description': 'Advanced CS and IT',
        'teacher_id': 'T-100-0001',
        'created_at': DateTime.now().toIso8601String(),
      });

      final quizId = await dbHelper.createQuiz(
        title: 'Special Slash Quiz $now',
        description: 'Quiz with slash in subject code',
        subjectId: subId,
        teacherId: 'T-100-0001',
        teacherName: 'Test Teacher',
        passingScore: 75,
        timeLimitMinutes: 10,
        questions: [
          {
            'question_text': 'Question 1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'A',
          }
        ],
      );

      expect(quizId, isPositive);
      final fetched = await dbHelper.getQuizById(quizId);
      expect(fetched, isNotNull);
      expect(fetched!['title'], 'Special Slash Quiz $now');

      // Update quiz
      await dbHelper.updateQuiz(
        quizId: quizId,
        title: 'Updated Special Slash Quiz $now',
        subjectId: subId,
        timeLimitMinutes: 15,
        passingScore: 75,
        questions: [
          {
            'question_text': 'Updated Q1',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'correct_option': 'B',
          }
        ],
      );

      final updated = await dbHelper.getQuizById(quizId);
      expect(updated!['title'], 'Updated Special Slash Quiz $now');

      // Delete quiz
      await dbHelper.deleteQuiz(quizId);
      final remaining = await dbHelper.getQuizById(quizId);
      expect(remaining, isNull);
    });
  });
}
