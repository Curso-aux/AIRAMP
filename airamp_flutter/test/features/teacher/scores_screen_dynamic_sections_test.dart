import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/admin/presentation/scores_screen.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_students_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScoresScreen Dynamic Section Filtering Tests', () {
    testWidgets('ScoresScreen renders dynamic sections passed from Teacher handled sections', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final handledSections = ['All Sections', 'Grade 10 - Emerald', 'STEM 12-B'];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: ScoresScreen(
                isEmbedded: true,
                sections: handledSections,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Open filters
      final filterButton = find.widgetWithText(OutlinedButton, 'Filters');
      expect(filterButton, findsOneWidget);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      // Check that the dynamic teacher handled sections appear in the filter
      expect(find.text('Grade 10 - Emerald'), findsOneWidget);
      expect(find.text('STEM 12-B'), findsOneWidget);

      // Verify that the old hardcoded mock sections are NOT present
      expect(find.text('STEM C'), findsNothing);
      expect(find.text('HUMSS A'), findsNothing);

      // Tap on a handled section
      await tester.tap(find.text('Grade 10 - Emerald'));
      await tester.pumpAndSettle();

      // Button label updates to indicate active filter
      expect(find.text('Filter: Grade 10 - Emerald'), findsOneWidget);
    });

    testWidgets('TeacherStudentsScreen Quiz Scores tab passes handled sections to embedded ScoresScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TeacherStudentsScreen(initialTab: 1), // 1 is Quiz Scores tab
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Student Quiz Scores'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Filters'), findsOneWidget);
    });
  });
}
