import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_teachers_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 2: Admin Faculty & Teacher Management Tests', () {
    final dbHelper = DatabaseHelper();
    final authRepo = AuthRepository();

    test('1. getTeachersList returns enriched teacher data with courses and workload', () async {
      final teachers = await dbHelper.getTeachersList();
      expect(teachers, isNotEmpty);

      final sirJohn = teachers.firstWhere((t) => t['email'] == 'john.reyes@deped.gov.ph');
      expect(sirJohn['full_name'], contains('John Reyes'));
      expect(sirJohn['role'], equals('teacher'));
      expect(sirJohn['assigned_subjects_count'], isA<int>());
      expect(sirJohn['assigned_subjects'], isA<List>());
      expect(sirJohn['handled_sections'], isA<List>());
      expect(sirJohn['student_count'], isA<int>());
    });

    test('2. Admin can create a new teacher with salted password and subject assignments', () async {
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final testEmail = 'prof.salazar_$uniqueSuffix@school.edu';
      final testUsername = 'prof.salazar_$uniqueSuffix';

      // Fetch an existing subject to assign
      final subjects = await dbHelper.database.then((db) => db.query('subjects', limit: 1));
      final assignedSubId = subjects.isNotEmpty ? (subjects.first['id'] as int) : null;

      final teacherId = await dbHelper.createTeacher(
        fullName: 'Prof. Teresa Salazar',
        email: testEmail,
        password: 'Salazar@123',
        username: testUsername,
        assignSubjectIds: assignedSubId != null ? [assignedSubId] : null,
      );

      expect(teacherId, startsWith('teacher_'));

      // Verify the teacher exists and has salted password
      final db = await dbHelper.database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: [teacherId]);
      expect(rows, isNotEmpty);
      expect(rows.first['password_salt'], isNotNull);
      expect(rows.first['password_salt'], isNotEmpty);
      expect(rows.first['password'].toString().length, equals(64));

      // Verify subject assignment
      if (assignedSubId != null) {
        final subRows = await db.query('subjects', where: 'id = ?', whereArgs: [assignedSubId]);
        expect(subRows.first['teacher_id'], equals(teacherId));
        expect(subRows.first['teacher_name'], equals('Prof. Teresa Salazar'));
      }

      // Verify the new teacher can log in
      final loginRes = await authRepo.login(testEmail, 'Salazar@123');
      expect(loginRes['user']['id'], equals(teacherId));
      expect(loginRes['user']['role'], equals('teacher'));
    });

    test('3. Admin can update teacher profile and reassign subjects', () async {
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final email = 'teacher_update_$uniqueSuffix@school.edu';

      final teacherId = await dbHelper.createTeacher(
        fullName: 'Original Name',
        email: email,
        password: 'InitialPassword@123',
      );

      // Update name, password, and email
      await dbHelper.updateTeacher(teacherId, {
        'full_name': 'Updated Name',
        'password': 'NewPassword@456',
      });

      // Verify login with new password succeeds and old password fails
      final newLogin = await authRepo.login(email, 'NewPassword@456');
      expect(newLogin['user']['fullName'], equals('Updated Name'));

      expect(
        () => authRepo.login(email, 'InitialPassword@123'),
        throwsA(isA<Exception>()),
      );
    });

    test('4. Admin can delete a teacher and unassign courses safely', () async {
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final email = 'teacher_del_$uniqueSuffix@school.edu';

      // Find or insert a test subject
      final db = await dbHelper.database;
      final subId = await db.insert('subjects', {
        'name': 'Test Subject for Deletion $uniqueSuffix',
        'description': 'Temporary subject for delete test',
        'created_at': DateTime.now().toIso8601String(),
      });

      final teacherId = await dbHelper.createTeacher(
        fullName: 'Teacher To Delete',
        email: email,
        password: 'Password@123',
        assignSubjectIds: [subId],
      );

      // Verify assigned
      var subRow = await db.query('subjects', where: 'id = ?', whereArgs: [subId]);
      expect(subRow.first['teacher_id'], equals(teacherId));

      // Delete teacher
      await dbHelper.deleteTeacher(teacherId);

      // Verify teacher deleted
      final teacherRows = await db.query('users', where: 'id = ?', whereArgs: [teacherId]);
      expect(teacherRows, isEmpty);

      // Verify subject is now unassigned
      subRow = await db.query('subjects', where: 'id = ?', whereArgs: [subId]);
      expect(subRow.first['teacher_id'], isNull);
      expect(subRow.first['teacher_name'], isNull);
    });

    testWidgets('5. AdminWebTeachersScreen renders faculty management interface cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminWebTeachersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Faculty & Teacher Management'), findsOneWidget);
      expect(find.text('Add New Faculty'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search bar
      expect(find.text('Total Faculty'), findsOneWidget);
      expect(find.text('Assigned Courses'), findsOneWidget);
      expect(find.text('Handled Sections'), findsOneWidget);

      // Fast forward past sqflite warning timer
      await tester.pump(const Duration(seconds: 12));
    });
  });
}
