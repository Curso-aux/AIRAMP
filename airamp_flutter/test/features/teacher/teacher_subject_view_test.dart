import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/presentation/subjects_mgmt_screen.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _mockUser;
  MockAuthNotifier(this._mockUser);

  @override
  User? build() => _mockUser;
}

class MockSubjectsNotifier extends SubjectsNotifier {
  final List<Map<String, dynamic>> _mockSubjects;
  String? lastUpdatedUnlockType;
  int? lastUpdatedSubjectId;

  MockSubjectsNotifier(this._mockSubjects);

  @override
  List<Map<String, dynamic>> build() {
    return _mockSubjects;
  }

  @override
  Future<void> updateUnlockType(int id, String unlockType) async {
    lastUpdatedSubjectId = id;
    lastUpdatedUnlockType = unlockType;
    for (int i = 0; i < _mockSubjects.length; i++) {
      if (_mockSubjects[i]['id'] == id) {
        _mockSubjects[i] = {..._mockSubjects[i], 'unlock_type': unlockType};
      }
    }
    state = List.from(_mockSubjects);
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Teacher Subject View & Role Permissions Tests', () {
    List<Map<String, dynamic>> getSampleSubjects() => [
      {
        'id': 101,
        'name': 'Web Development Fundamentals',
        'subject_code': 'CS101',
        'description': 'HTML, CSS, and modern JS',
        'grade_level': 'Grade 10',
        'semester': '1st Semester',
        'unlock_type': 'Sequential',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
      },
      {
        'id': 102,
        'name': 'Data Structures & Algorithms',
        'subject_code': 'CS202',
        'description': 'Advanced programming',
        'grade_level': 'Grade 11',
        'semester': '2nd Semester',
        'unlock_type': 'Flexible',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
      },
    ];

    testWidgets('1. Teacher role: Edit subject button is removed while Unlock type and Semester are visible', (tester) async {
      final teacherUser = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        fullName: 'Sir John Reyes',
        role: 'teacher',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(teacherUser)),
            subjectsProvider.overrideWith(() => MockSubjectsNotifier(getSampleSubjects())),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SubjectsMgmtScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Subject names must be visible
      expect(find.text('Web Development Fundamentals'), findsOneWidget);
      expect(find.text('Data Structures & Algorithms'), findsOneWidget);

      // Unlock type badges MUST be displayed
      expect(find.text('Sequential'), findsOneWidget);
      expect(find.text('Flexible'), findsOneWidget);

      // Semester badges MUST be displayed
      expect(find.text('1st Semester'), findsOneWidget);
      expect(find.text('2nd Semester'), findsOneWidget);

      // Edit button (Icons.edit_outlined) MUST NOT be present for teacher
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      // Teacher curriculum action indicator MUST be present
      expect(find.text('Curriculum'), findsNWidgets(2));
    });

    testWidgets('2. Admin role: Edit subject button is visible alongside Unlock type and Semester', (tester) async {
      final adminUser = User(
        id: 'admin_1',
        email: 'aira@admin',
        fullName: 'Aira Admin',
        role: 'admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(adminUser)),
            subjectsProvider.overrideWith(() => MockSubjectsNotifier(getSampleSubjects())),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SubjectsMgmtScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Both badges must be visible
      expect(find.text('Sequential'), findsOneWidget);
      expect(find.text('1st Semester'), findsOneWidget);

      // Edit button (Icons.edit_outlined) MUST be present for admin
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));

      // Delete button (Icons.delete_outline) MUST be present for admin
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    });

    testWidgets('3. Teacher can set Progression Mode to Sequential or Flexible via interactive badge', (tester) async {
      final teacherUser = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        fullName: 'Sir John Reyes',
        role: 'teacher',
      );

      final mockNotifier = MockSubjectsNotifier(getSampleSubjects());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(teacherUser)),
            subjectsProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SubjectsMgmtScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the "Sequential" badge on the first subject
      await tester.tap(find.text('Sequential'));
      await tester.pumpAndSettle();

      // Modal title must appear
      expect(find.text('Curriculum Progression Mode'), findsOneWidget);
      expect(find.text('Sequential Progression'), findsOneWidget);
      expect(find.text('Flexible Progression'), findsOneWidget);

      // Tap on Flexible Progression option
      await tester.tap(find.text('Flexible Progression'));
      await tester.pumpAndSettle();

      // Tap Save Progression Mode button
      await tester.tap(find.text('Save Progression Mode'));
      await tester.pumpAndSettle();

      // Verify that mockNotifier received the update
      expect(mockNotifier.lastUpdatedSubjectId, equals(101));
      expect(mockNotifier.lastUpdatedUnlockType, equals('Flexible'));
    });

    test('4. DatabaseHelper updates and persists subject unlock_type properly', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final subId = await db.insert('subjects', {
        'name': 'Progression Test Subject $now',
        'subject_code': 'PROG-$now',
        'description': 'Testing unlock type updates',
        'unlock_type': 'Sequential',
        'semester': '1st Semester',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update to Flexible
      await dbHelper.updateSubjectUnlockType(subId, 'Flexible');

      final updated = await db.query('subjects', where: 'id = ?', whereArgs: [subId]);
      expect(updated.first['unlock_type'], equals('Flexible'));
      expect(updated.first['semester'], equals('1st Semester'));

      // Update back to Sequential
      await dbHelper.updateSubjectUnlockType(subId, 'Sequential');
      final reverted = await db.query('subjects', where: 'id = ?', whereArgs: [subId]);
      expect(reverted.first['unlock_type'], equals('Sequential'));
    });
  });
}
