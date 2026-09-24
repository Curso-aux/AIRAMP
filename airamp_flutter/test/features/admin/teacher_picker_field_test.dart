import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/components/teacher_picker_field.dart';

void main() {
  final testTeachers = [
    {
      'id': 'teacher_1',
      'full_name': 'Sir John Reyes',
      'email': 'john.reyes@deped.gov.ph',
      'username': 'john.reyes',
      'assigned_subjects_count': 2,
    },
    {
      'id': 'teacher_2',
      'full_name': 'Ma\'am Maria Santos',
      'email': 'maria.santos@deped.gov.ph',
      'username': 'maria.santos',
      'assigned_subjects_count': 4,
    },
    {
      'id': 'teacher_3',
      'full_name': 'Mr. Carlos Mendoza',
      'email': 'carlos.mendoza@deped.gov.ph',
      'username': 'carlos.m',
      'assigned_subjects_count': 0,
    },
  ];

  Widget buildTestWidget({
    String? selectedId,
    String? selectedName,
    required ValueChanged<Map<String, dynamic>?> onSelect,
  }) {
    return ProviderScope(
      overrides: [
        teachersListProvider.overrideWith((ref) async => testTeachers),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TeacherPickerField(
              selectedTeacherId: selectedId,
              selectedTeacherName: selectedName,
              onTeacherSelected: onSelect,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('TeacherPickerField displays unassigned state initially', (tester) async {
    await tester.pumpWidget(buildTestWidget(onSelect: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Assigned Faculty / Teacher'), findsOneWidget);
    expect(find.text('Unassigned / To Be Designated'), findsOneWidget);
    expect(find.text('Tap to search & assign teacher'), findsOneWidget);
    expect(find.text('Clear Assignment'), findsNothing);
  });

  testWidgets('TeacherPickerField displays selected teacher and clear button', (tester) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      buildTestWidget(
        selectedId: 'teacher_1',
        selectedName: 'Sir John Reyes',
        onSelect: (t) => selected = t,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sir John Reyes'), findsOneWidget);
    expect(find.text('Clear Assignment'), findsOneWidget);

    // Tap Clear Assignment
    await tester.tap(find.text('Clear Assignment'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('TeacherPickerField search by name filters list with debounce', (tester) async {
    Map<String, dynamic>? picked;
    await tester.pumpWidget(
      buildTestWidget(
        onSelect: (t) => picked = t,
      ),
    );
    await tester.pumpAndSettle();

    // Tap to open search modal
    await tester.tap(find.text('Unassigned / To Be Designated'));
    await tester.pumpAndSettle();

    expect(find.text('Assign Faculty / Teacher'), findsOneWidget);
    expect(find.text('Sir John Reyes'), findsOneWidget);
    expect(find.text('Ma\'am Maria Santos'), findsOneWidget);
    expect(find.text('Mr. Carlos Mendoza'), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(TextField), 'carlos');
    // Debounce duration 200ms
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Mr. Carlos Mendoza'), findsOneWidget);
    expect(find.text('Sir John Reyes'), findsNothing);
    expect(find.text('Ma\'am Maria Santos'), findsNothing);

    // Select Carlos Mendoza
    await tester.tap(find.text('Mr. Carlos Mendoza'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!['id'], equals('teacher_3'));
  });

  testWidgets('TeacherPickerField search by email matches teacher', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        onSelect: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unassigned / To Be Designated'));
    await tester.pumpAndSettle();

    // Search by email
    await tester.enterText(find.byType(TextField), 'maria.santos@deped');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Ma\'am Maria Santos'), findsOneWidget);
    expect(find.text('Sir John Reyes'), findsNothing);
  });

  testWidgets('TeacherPickerField displays empty state when query returns no teacher', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        onSelect: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Unassigned / To Be Designated'));
    await tester.pumpAndSettle();

    // Search for non-existent teacher
    await tester.enterText(find.byType(TextField), 'ZzzUnknownPerson');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('No teacher found'), findsOneWidget);
    expect(find.text('Clear search'), findsOneWidget);

    // Tap clear search
    await tester.tap(find.text('Clear search'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Sir John Reyes'), findsOneWidget);
    expect(find.text('No teacher found'), findsNothing);
  });
}
