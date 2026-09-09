import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_students_screen.dart';

class MockAdminStudentsNotifier extends AdminStudentsNotifier {
  final List<Map<String, dynamic>> _mockList;
  MockAdminStudentsNotifier(this._mockList);

  @override
  List<Map<String, dynamic>> build() {
    return _mockList;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 3: Dynamic Subject Enrollment & Admin Student Control Tests', () {
    final dbHelper = DatabaseHelper();

    test('1. getStudentEnrollmentsWithDetails returns all subjects with enrollment status', () async {
      final details = await dbHelper.getStudentEnrollmentsWithDetails('student_1');
      expect(details, isNotEmpty);

      // Student 1 (Maria Lopez) is pre-enrolled in CS101
      final cs101 = details.firstWhere((d) => d['subject_code'] == 'CS101');
      expect(cs101['is_enrolled'], isTrue);
      expect(cs101['enrolled_at'], isNotNull);
    });

    test('2. Admin can dynamically update student enrollments via setStudentEnrollments', () async {
      final db = await dbHelper.database;
      final testStudentId = 'student_test_${DateTime.now().millisecondsSinceEpoch}';

      // Insert test student
      await db.insert('users', {
        'id': testStudentId,
        'email': '$testStudentId@school.edu',
        'username': testStudentId,
        'password': 'HashedPassword123',
        'role': 'student',
        'full_name': 'Enrollment Test Student',
        'section': 'Emerald',
        'grade': 'Grade 10',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Fetch all subjects
      final subjects = await db.query('subjects');
      expect(subjects.length, greaterThanOrEqualTo(2));

      final sub1Id = subjects[0]['id'] as int;
      final sub2Id = subjects[1]['id'] as int;

      // Enroll in sub1 only
      await dbHelper.setStudentEnrollments(testStudentId, [sub1Id]);
      var enrolled = await dbHelper.getEnrolledSubjects(testStudentId);
      expect(enrolled.map((e) => e['id']), contains(sub1Id));
      expect(enrolled.map((e) => e['id']), isNot(contains(sub2Id)));

      // Admin customizes to both sub1 and sub2
      await dbHelper.setStudentEnrollments(testStudentId, [sub1Id, sub2Id]);
      enrolled = await dbHelper.getEnrolledSubjects(testStudentId);
      expect(enrolled.map((e) => e['id']), containsAll([sub1Id, sub2Id]));

      // Admin removes sub1 and leaves sub2
      await dbHelper.setStudentEnrollments(testStudentId, [sub2Id]);
      enrolled = await dbHelper.getEnrolledSubjects(testStudentId);
      expect(enrolled.map((e) => e['id']), contains(sub2Id));
      expect(enrolled.map((e) => e['id']), isNot(contains(sub1Id)));
    });

    testWidgets('3. AdminWebStudentsScreen renders "Courses" button for each student', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockStudents = [
        {
          'id': 'student_1',
          'full_name': 'Maria Lopez',
          'email': 'maria@test.com',
          'section': 'Emerald',
          'grade': 'Grade 10',
          'enrolled_courses': 2,
          'avg_score': 88,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            availableSectionsProvider.overrideWith((ref) => ['Emerald', 'Ruby']),
            adminStudentsProvider.overrideWith(() => MockAdminStudentsNotifier(mockStudents)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AdminWebStudentsScreen()),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Student Management & Section Arrangement'), findsOneWidget);
      // "Courses" button must be visible in the actions column
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Move / Assign'), findsOneWidget);
    });
  });
}
