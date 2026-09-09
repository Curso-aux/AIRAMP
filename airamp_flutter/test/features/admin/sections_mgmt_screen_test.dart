import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/admin/presentation/sections_mgmt_screen.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

// Fake Notifier providing mock sections for testing
class MockSectionsNotifier extends SectionsNotifier {
  final List<Map<String, dynamic>> _mockSections;
  MockSectionsNotifier(this._mockSections);

  @override
  List<Map<String, dynamic>> build() {
    return _mockSections;
  }
}

void main() {
  final mockSections = [
    {
      'id': 1,
      'name': 'Grade 10 - Emerald',
      'description': 'Junior High Class Emerald',
      'grade': 'Grade 10',
      'room': 'Room 201 - Main Bldg',
      'student_count': 3,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 2,
      'name': 'Grade 11 - STEM B',
      'description': 'Senior High STEM Strand',
      'grade': 'Grade 11',
      'room': 'Room 304 - Science Bldg',
      'student_count': 1,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  Widget createWidgetUnderTest({List<Map<String, dynamic>>? customSections}) {
    return ProviderScope(
      overrides: [
        sectionsProvider.overrideWith(() => MockSectionsNotifier(customSections ?? mockSections)),
      ],
      child: const MaterialApp(
        home: SectionsMgmtScreen(),
      ),
    );
  }

  group('SectionsMgmtScreen - Grade Level Separation Tests', () {
    testWidgets('Renders header, grade filter chips with count badges, and add button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Manage Sections'), findsOneWidget);
      expect(find.text('2 active sections · Separated by grade level'), findsOneWidget);
      expect(find.text('Add Section'), findsOneWidget);

      // Verify filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Grade 10'), findsWidgets);
      expect(find.text('Grade 11'), findsWidgets);
      expect(find.text('Grade 7'), findsWidgets);
      expect(find.text('Grade 8'), findsWidgets);
      expect(find.text('Grade 9'), findsWidgets);
      expect(find.text('Grade 12'), findsWidgets);
    });

    testWidgets('Separates sections into distinct grade level group headers when All is selected', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Group headers for Grade 10 and Grade 11
      expect(find.text('Junior High School'), findsOneWidget);
      expect(find.text('Senior High School'), findsOneWidget);

      // Section cards
      expect(find.text('Grade 10 - Emerald'), findsOneWidget);
      expect(find.text('Grade 11 - STEM B'), findsOneWidget);
    });

    testWidgets('Selecting Grade 10 filter chip filters exclusively to Grade 10 sections', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Grade 10 filter chip
      final grade10Chip = find.widgetWithText(FilterChip, 'Grade 10');
      await tester.tap(grade10Chip);
      await tester.pumpAndSettle();

      expect(find.text('Grade 10 - Emerald'), findsOneWidget);
      expect(find.text('Grade 11 - STEM B'), findsNothing);
    });

    testWidgets('Selecting an empty grade (Grade 7) shows friendly empty state with create button', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Grade 7 filter chip
      final grade7Chip = find.widgetWithText(FilterChip, 'Grade 7');
      await tester.tap(grade7Chip);
      await tester.pumpAndSettle();

      expect(find.text('No sections created for Grade 7 yet'), findsOneWidget);
      expect(find.text('Create Grade 7 Section'), findsOneWidget);

      // Tap on Create Grade 7 Section button to open modal dialog
      await tester.tap(find.text('Create Grade 7 Section'));
      await tester.pumpAndSettle();

      // Verify modal dialog appeared
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add New Section'), findsOneWidget);
      expect(find.text('Create Section'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Tapping Add Section header button opens modal dialog with form validation', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap main Add Section button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Section'));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Add New Section'), findsOneWidget);
      expect(find.text('Assign Grade Level'), findsOneWidget);

      // Try to submit with empty name
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Section'));
      await tester.pumpAndSettle();

      // Validation error shown
      expect(find.text('Please enter section name'), findsOneWidget);

      // Cancel closes modal
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
