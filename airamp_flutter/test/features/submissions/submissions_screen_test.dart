import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/submissions/presentation/submissions_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _mockUser;
  MockAuthNotifier(this._mockUser);

  @override
  User? build() => _mockUser;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SubmissionsScreen Widget & Integration Tests', () {
    final dbHelper = DatabaseHelper();

    testWidgets('1. SubmissionsScreen loads assignment from DB and renders details', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = await dbHelper.database;

      final subjectId = await db.insert('subjects', {
        'name': 'Widget Test Subject $now',
        'subject_code': 'WID-$now',
        'description': 'Testing SubmissionsScreen rendering',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Final Portfolio & Widget Project $now',
        description: 'Submit your Flutter source code link or bundle file for assessment.',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        teacherName: 'Sir John Reyes',
        totalPoints: 100,
        dueDate: DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(
            User(
              id: 'test_student_screen',
              email: 'student@test.com',
              role: 'student',
              fullName: 'Screen Test Student',
            ),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SubmissionsScreen(assignmentId: assignmentId.toString()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Final Portfolio & Widget Project $now'), findsOneWidget);
      expect(find.textContaining('100 pts'), findsOneWidget);
      expect(find.textContaining('Sir John Reyes'), findsOneWidget);
      expect(find.textContaining('Submit your Flutter source code link'), findsOneWidget);
      expect(find.text('Submit Assignment'), findsWidgets);
    });

    testWidgets('2. Submitting a link transitions screen to submitted view', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_flow_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'password': 'pass',
        'role': 'student',
        'full_name': 'Flow Student',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Submission Flow Subject $now',
        'subject_code': 'SFS-$now',
        'description': 'Testing submission flow',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Project Submission Flow $now',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        dueDate: DateTime.now().add(const Duration(days: 10)).toIso8601String(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(
            User(
              id: studentId,
              email: '$studentId@school.edu',
              role: 'student',
              fullName: 'Flow Student',
            ),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SubmissionsScreen(assignmentId: assignmentId.toString()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter link in text field
      final linkField = find.byType(TextField).first;
      await tester.enterText(linkField, 'https://github.com/flowstudent/flutter-app');
      await tester.pumpAndSettle();

      // Tap Submit Assignment button
      final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Assignment');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify success state displayed
      expect(find.text('Submitted Successfully!'), findsOneWidget);
      expect(find.text('https://github.com/flowstudent/flutter-app'), findsOneWidget);
      expect(find.text('Edit / Resubmit'), findsOneWidget);

      // Verify saved in DB
      final savedSub = await dbHelper.getSubmissionForAssignment(assignmentId, studentId);
      expect(savedSub, isNotNull);
      expect(savedSub!['content_link'], 'https://github.com/flowstudent/flutter-app');
    });

    testWidgets('3. Graded submission displays score and teacher feedback', (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final studentId = 'student_graded_$now';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': studentId,
        'email': '$studentId@school.edu',
        'password': 'pass',
        'role': 'student',
        'full_name': 'Graded Student',
        'created_at': DateTime.now().toIso8601String(),
      });

      final subjectId = await db.insert('subjects', {
        'name': 'Grading Flow Subject $now',
        'subject_code': 'GFS-$now',
        'description': 'Testing grading view',
        'teacher_id': 'teacher_1',
        'created_at': DateTime.now().toIso8601String(),
      });

      final assignmentId = await dbHelper.createAssignment(
        title: 'Graded Assignment $now',
        subjectId: subjectId,
        teacherId: 'teacher_1',
        totalPoints: 100,
      );

      final subId = await dbHelper.submitAssignment(
        assignmentId: assignmentId,
        studentId: studentId,
        submissionType: 'link',
        contentLink: 'https://github.com/graded/repo',
        notes: 'Final commit ready for evaluation.',
      );

      await dbHelper.gradeSubmission(
        submissionId: subId,
        grade: 98.0,
        feedback: 'Superb architecture and test coverage!',
        gradedBy: 'Sir John Reyes',
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(
            User(
              id: studentId,
              email: '$studentId@school.edu',
              role: 'student',
              fullName: 'Graded Student',
            ),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SubmissionsScreen(assignmentId: assignmentId.toString()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Assignment Graded'), findsOneWidget);
      expect(find.text('98 / 100 pts'), findsOneWidget);
      expect(find.text('Superb architecture and test coverage!'), findsOneWidget);
    });
  });
}
