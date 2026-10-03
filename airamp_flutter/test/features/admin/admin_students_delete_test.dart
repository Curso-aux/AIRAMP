import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_students_screen.dart';

class MockAdminStudentsNotifier extends AdminStudentsNotifier {
  final List<Map<String, dynamic>> _mock;
  MockAdminStudentsNotifier(this._mock);

  @override
  List<Map<String, dynamic>> build() => _mock;

  @override
  Future<void> loadStudents({String? section, String? grade, String? query}) async {
    state = _mock;
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    state = state.where((s) => s['id'] != studentId).toList();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Admin Student Deletion & Cascading Cleanup Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. DatabaseHelper.deleteStudent permanently removes student and cascades enrollments & progress', () async {
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final testStudentId = 'test_student_$uniqueSuffix';
      final db = await dbHelper.database;

      // 1. Insert directly into users table with all required fields
      await db.insert('users', {
        'id': testStudentId,
        'full_name': 'Test Deletion Student',
        'email': 'delete.student_$uniqueSuffix@school.edu',
        'password': 'hashed_password_sample',
        'password_salt': 'salt_sample',
        'role': 'student',
        'grade': 'Grade 10',
        'section': 'Emerald',
        'student_type': 'regular',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 2. Add an enrollment
      await db.insert('enrollments', {
        'student_id': testStudentId,
        'subject_id': 1,
        'status': 'active',
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      // 3. Add progress with subject_id
      await db.insert('student_progress', {
        'student_id': testStudentId,
        'subject_id': 1,
        'lo_id': 1,
        'completed_at': DateTime.now().toIso8601String(),
      });

      // Verify records exist
      var userRows = await db.query('users', where: 'id = ?', whereArgs: [testStudentId]);
      var enrollRows = await db.query('enrollments', where: 'student_id = ?', whereArgs: [testStudentId]);
      var progRows = await db.query('student_progress', where: 'student_id = ?', whereArgs: [testStudentId]);

      expect(userRows, isNotEmpty);
      expect(enrollRows, isNotEmpty);
      expect(progRows, isNotEmpty);

      // Execute deleteStudent
      await dbHelper.deleteStudent(testStudentId);

      // Verify all cleaned up
      userRows = await db.query('users', where: 'id = ?', whereArgs: [testStudentId]);
      enrollRows = await db.query('enrollments', where: 'student_id = ?', whereArgs: [testStudentId]);
      progRows = await db.query('student_progress', where: 'student_id = ?', whereArgs: [testStudentId]);

      expect(userRows, isEmpty);
      expect(enrollRows, isEmpty);
      expect(progRows, isEmpty);
    });

    test('2. AdminStudentsNotifier.deleteStudent cleans up student and refreshes list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch + 1;
      final testStudentId = 'notif_student_$uniqueSuffix';
      final db = await dbHelper.database;

      await db.insert('users', {
        'id': testStudentId,
        'full_name': 'Notifier Delete Target',
        'email': 'notif.delete_$uniqueSuffix@school.edu',
        'password': 'hashed_password_sample',
        'password_salt': 'salt_sample',
        'role': 'student',
        'grade': 'Grade 9',
        'section': 'Ruby',
        'student_type': 'regular',
        'created_at': DateTime.now().toIso8601String(),
      });

      await container.read(adminStudentsProvider.notifier).loadStudents();
      var students = container.read(adminStudentsProvider);
      expect(students.any((s) => s['id'] == testStudentId), isTrue);

      // Call notifier delete
      await container.read(adminStudentsProvider.notifier).deleteStudent(testStudentId);

      students = container.read(adminStudentsProvider);
      expect(students.any((s) => s['id'] == testStudentId), isFalse);
    });

    testWidgets('3. AdminWebStudentsScreen renders ACTIONS header and trash icon button with confirmation dialog', (tester) async {
      final mockStudents = [
        {
          'id': '001-0001',
          'full_name': 'Juan Dela Cruz',
          'email': 'juan@school.edu',
          'section': 'Emerald',
          'grade': 'Grade 10',
          'student_type': 'regular',
          'enrolled_courses': 2,
          'avg_score': 90,
        },
      ];

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminStudentsProvider.overrideWith(() => MockAdminStudentsNotifier(mockStudents)),
            availableSectionsProvider.overrideWith((ref) => ['Emerald', 'Ruby']),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: AdminWebStudentsScreen()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Check for ACTIONS column header
      expect(find.text('ACTIONS'), findsOneWidget);

      // Check for delete icon
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsWidgets);

      // Ensure visible and tap the delete button to verify confirmation modal opens
      await tester.ensureVisible(deleteButtons.first);
      await tester.tap(deleteButtons.first);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Delete Student Record'), findsOneWidget);
      expect(find.text('Delete Student'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.textContaining('Juan Dela Cruz'), findsWidgets);
      expect(find.textContaining('001-0001'), findsWidgets);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));

      // Fast-forward past sqflite internal warning timer
      await tester.pump(const Duration(seconds: 12));
    });
  });
}
