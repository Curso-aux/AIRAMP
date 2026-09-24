import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/class_overview_widget.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';

void main() {
  final sampleStudents = List.generate(
    6,
    (i) => {
      'id': 'student_$i',
      'full_name': 'Student Name $i',
      'section': i.isEven ? 'Emerald' : 'Sapphire',
      'completed_los': i,
      'enrolled_subjects': 2,
    },
  );

  Widget createWidget({Size screenSize = const Size(360, 640)}) {
    return ProviderScope(
      overrides: [
        teacherHandledSectionsProvider.overrideWith(
          (ref) async => ['Emerald', 'Sapphire'],
        ),
        teacherStudentsProvider.overrideWith(
          () => _FakeTeacherStudentsNotifier(sampleStudents),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const Scaffold(
            body: SingleChildScrollView(
              child: ClassOverviewWidget(),
            ),
          ),
        ),
      ),
    );
  }

  group('ClassOverviewWidget Responsive & Data-Overwhelm Tests', () {
    testWidgets('1. Renders cleanly on a small screen (360px) without any RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget(screenSize: const Size(360, 640)));
      await tester.pumpAndSettle();

      expect(find.text('Class Overview & Student Activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Shows maximum 3 students by default to avoid overwhelming the user', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Should show Show More button with count of remaining
      expect(find.text('Show More (3 more)'), findsOneWidget);

      // Student items rendered should be 3
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('3. Tapping Show More reveals all students and shows Show Less', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap Show More
      await tester.tap(find.text('Show More (3 more)'));
      await tester.pumpAndSettle();

      // Now all 6 students should be displayed
      expect(find.byType(LinearProgressIndicator), findsNWidgets(6));
      expect(find.text('Show Less'), findsOneWidget);

      // Tap Show Less to collapse back to 3
      await tester.tap(find.text('Show Less'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      expect(find.text('Show More (3 more)'), findsOneWidget);
    });

    testWidgets('4. Section collapse toggle hides student list entirely', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap the collapse toggle in header
      final toggleButton = find.byTooltip('Collapse Student List');
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Student rows should now be collapsed
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Collapsed'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.textContaining('Collapsed'));
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('5. Section and Status filter dropdowns exist and render properly', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Check Dropdowns exist
      expect(find.byType(DropdownButton<String>), findsNWidgets(2));
      expect(find.text('All Handled Sections'), findsOneWidget);
      expect(find.text('All Status'), findsOneWidget);
    });
  });
}

class _FakeTeacherStudentsNotifier extends TeacherStudentsNotifier {
  final List<Map<String, dynamic>> _mock;
  _FakeTeacherStudentsNotifier(this._mock);

  @override
  List<Map<String, dynamic>> build() => _mock;

  @override
  Future<void> reload({String? section, String? query}) async {}
}
