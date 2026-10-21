import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/lo_mastery_matrix.dart';

void main() {
  Widget buildMatrix({Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: const Scaffold(
          body: SingleChildScrollView(
            child: LoMasteryMatrix(),
          ),
        ),
      ),
    );
  }

  group('LoMasteryMatrix UI & Mobile UX Tests', () {
    testWidgets('1. Renders title, balanced filter rows, and defaults to Expandable Cards on mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildMatrix(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Header and description
      expect(find.text('Curriculum Competencies by Class Section'), findsOneWidget);
      expect(find.text('Proficient (80%+)'), findsOneWidget);
      expect(find.text('Developing (60% – 79%)'), findsOneWidget);
      expect(find.text('Needs Help (Below 60%)'), findsOneWidget);

      // Balanced filter rows
      expect(find.text('All Subjects'), findsOneWidget);
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Defaults to Expandable Cards mode on mobile (LO-01 expanded by default)
      expect(find.text('LO-01'), findsOneWidget);
      expect(find.text('11-STEM-A'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('2. Tapping competency card header collapses and expands section breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildMatrix(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // LO-01 starts expanded
      expect(find.text('11-STEM-A'), findsWidgets);

      // Tap LO-01 to collapse
      await tester.tap(find.text('LO-01'));
      await tester.pumpAndSettle();

      // Progress bars for LO-01 should now be collapsed
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // Tap LO-01 again to re-expand
      await tester.tap(find.text('LO-01'));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('3. Can switch between Expandable Cards view and Heatmap Matrix Grid view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildMatrix(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Switch to Grid/Table mode using explicit toggle key
      await tester.tap(find.byKey(const Key('view_mode_grid')));
      await tester.pumpAndSettle();

      // Matrix header should now be visible
      expect(find.text('COMPETENCY'), findsOneWidget);
      expect(find.text('Class Avg'), findsWidgets);

      // Switch back to Cards mode using explicit toggle key
      await tester.tap(find.byKey(const Key('view_mode_cards')));
      await tester.pumpAndSettle();

      expect(find.text('COMPETENCY'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('4. Tapping a section row in cards view opens detailed drill-down modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(buildMatrix(size: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Tap first section row (11-STEM-A)
      final sectionItem = find.text('11-STEM-A').first;
      await tester.tap(sectionItem);
      await tester.pumpAndSettle();

      // Drill down modal content should appear
      expect(find.text('Average Student Score'), findsOneWidget);
      expect(find.text('Most-Missed Assessment Items & Misconceptions'), findsOneWidget);
      expect(find.text('Suggested Teaching Strategy'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Average Student Score'), findsNothing);
    });
  });
}
