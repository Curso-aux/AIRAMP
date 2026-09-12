import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
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
}

void main() {
  final mockStudents = [
    {
      'id': 's1',
      'full_name': 'Angela Santos',
      'email': 'angela@school.edu',
      'section': 'Grade 11 - STEM B',
      'grade': 'Grade 11',
      'student_type': 'regular',
      'enrolled_courses': 1,
      'avg_score': 85,
    },
    {
      'id': 's2',
      'full_name': 'Juan Dela Cruz',
      'email': 'juan@school.edu',
      'section': 'Grade 10 - Emerald',
      'grade': 'Grade 10',
      'student_type': 'regular',
      'enrolled_courses': 2,
      'avg_score': 90,
    },
    {
      'id': 's3',
      'full_name': 'Maria Lopez',
      'email': 'maria@school.edu',
      'section': 'Grade 10 - Emerald',
      'grade': 'Grade 10',
      'student_type': 'regular',
      'enrolled_courses': 3,
      'avg_score': 95,
    },
    {
      'id': 's4',
      'full_name': 'Alex Irregular',
      'email': 'alex@school.edu',
      'section': 'Unassigned',
      'grade': 'Grade 10',
      'student_type': 'irregular',
      'special_notes': 'Cross-enrolled in Grade 11 Physics',
      'enrolled_courses': 1,
      'avg_score': 78,
    },
  ];

  Widget buildWidget() {
    return ProviderScope(
      overrides: [
        adminStudentsProvider.overrideWith(() => MockAdminStudentsNotifier(mockStudents)),
        availableSectionsProvider.overrideWith((ref) => ['Grade 10 - Emerald', 'Grade 11 - STEM B']),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: AdminWebStudentsScreen()),
      ),
    );
  }

  group('Student Directory Hierarchy & Special Students Tests', () {
    testWidgets('1. Separates grades: Year Level Step 1 shows Grade 10 by default without bundling Grade 11', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Header and hierarchy steps exist
      expect(find.text('Student Management & Section Arrangement'), findsOneWidget);
      expect(find.text('Choose Year Level:'), findsOneWidget);

      // Grade 10 students are shown
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('Maria Lopez'), findsOneWidget);

      // Grade 11 student (Angela Santos) is NOT bundled in Grade 10 view
      expect(find.text('Angela Santos'), findsNothing);

      // Step 2 shows classrooms for Grade 10
      expect(find.textContaining('Choose Classroom in Grade 10'), findsOneWidget);
    });

    testWidgets('2. Switching Year Level to Grade 11 shows Grade 11 students and classrooms', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Grade 11 chip
      final grade11Chip = find.textContaining('Grade 11');
      expect(grade11Chip, findsWidgets);
      await tester.tap(grade11Chip.first);
      await tester.pump(const Duration(milliseconds: 100));

      // Now Angela Santos (Grade 11) is displayed
      expect(find.text('Angela Santos'), findsOneWidget);

      // Grade 10 students are not visible
      expect(find.text('Juan Dela Cruz'), findsNothing);
      expect(find.text('Maria Lopez'), findsNothing);
    });

    testWidgets('3. Special Students tab isolates irregular and unassigned students', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Special Students chip
      final specialChip = find.textContaining('Special Students');
      expect(specialChip, findsOneWidget);
      await tester.tap(specialChip);
      await tester.pump(const Duration(milliseconds: 100));

      // Special student Alex Irregular is displayed
      expect(find.text('Alex Irregular'), findsOneWidget);

      // Regular students are not in the special students hub
      expect(find.text('Juan Dela Cruz'), findsNothing);
      expect(find.text('Maria Lopez'), findsNothing);

      // Category filters exist
      expect(find.text('Special Student Category:'), findsOneWidget);
      expect(find.text('Irregular'), findsOneWidget);
      expect(find.text('SPED'), findsOneWidget);
      expect(find.text('Unassigned'), findsWidgets);
    });
  });
}
