import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_students_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Teacher Handled Sections and Section Student Roster Tests', () {
    test('1. Teacher can retrieve handled sections with full metadata and student counts', () async {
      final helper = DatabaseHelper();
      final sectionDetails = await helper.getHandledSectionsWithDetails('teacher_1');

      expect(sectionDetails, isNotEmpty);

      final sectionNames = sectionDetails.map((s) => s['name'] as String).toList();
      expect(sectionNames.any((n) => n.contains('Emerald')), isTrue, reason: 'Emerald must be among handled sections');

      final emerald = sectionDetails.firstWhere((s) => (s['name'] as String).contains('Emerald'));
      expect(emerald['student_count'], greaterThanOrEqualTo(1));
      expect(emerald['grade'], isNotEmpty);
      expect(emerald['subjects'], isA<List<String>>());
    });

    test('2. Querying students for Emerald returns all students in that section', () async {
      final helper = DatabaseHelper();
      final students = await helper.getStudentsForTeacher('teacher_1', section: 'Emerald');

      expect(students, isNotEmpty);
      for (final s in students) {
        expect(s['section'], contains('Emerald'));
        expect(s['full_name'], isNotEmpty);
        expect(s['email'], isNotEmpty);
        expect(s['completed_los'], isA<int>());
        expect(s['enrolled_subjects'], isA<int>());
      }

      final studentNames = students.map((s) => s['full_name'] as String).toList();
      expect(studentNames.contains('Maria Lopez'), isTrue);
    });

    test('3. Querying students for a different handled section filters exclusively to that section', () async {
      final helper = DatabaseHelper();
      final emeraldStudents = await helper.getStudentsForTeacher('teacher_1', section: 'Emerald');
      final stemStudents = await helper.getStudentsForTeacher('teacher_1', section: 'STEM B');

      final emeraldIds = emeraldStudents.map((s) => s['id'] as String).toSet();
      for (final stemStudent in stemStudents) {
        expect(emeraldIds.contains(stemStudent['id']), isFalse, reason: 'STEM student must not appear in Emerald filter');
        expect(stemStudent['section'], contains('STEM B'));
      }
    });

    test('4. Search query within a section filters students correctly', () async {
      final helper = DatabaseHelper();
      final mariaResults = await helper.getStudentsForTeacher('teacher_1', section: 'Emerald', query: 'Maria');

      expect(mariaResults.isNotEmpty, isTrue);
      expect(mariaResults.every((s) => (s['full_name'] as String).toLowerCase().contains('maria')), isTrue);

      final noResults = await helper.getStudentsForTeacher('teacher_1', section: 'Emerald', query: 'NonExistentXYZ');
      expect(noResults.isEmpty, isTrue);
    });

    test('5. Teacher can retrieve All Sections roster containing all students across classes', () async {
      final helper = DatabaseHelper();
      final allStudents = await helper.getStudentsForTeacher('teacher_1', section: 'All Sections');

      expect(allStudents.length, greaterThanOrEqualTo(1));
      final sectionsFound = allStudents.map((s) => s['section'] as String).toSet();
      expect(sectionsFound.any((s) => s.contains('Emerald')), isTrue);
    });

    testWidgets('6. TeacherStudentsScreen renders Handled Section cards and student roster', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherStudentsScreen(initialSection: 'Emerald'),
          ),
        ),
      );

      await tester.pump();
      // Advance fake timers to settle sqflite 10-second connection timeout
      await tester.pump(const Duration(seconds: 11));

      expect(find.text('Handled Sections & Roster'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
