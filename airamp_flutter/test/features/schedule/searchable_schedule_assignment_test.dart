import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/aira_search_picker_modal.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/create_edit_schedule_dialog.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

class _MockAdminTeachersNotifier extends AdminTeachersNotifier {
  final List<Map<String, dynamic>> _initial;
  _MockAdminTeachersNotifier(this._initial);
  @override
  List<Map<String, dynamic>> build() => _initial;
  @override
  Future<void> loadTeachers({bool syncCloud = true}) async {}
}

class _MockSubjectsNotifier extends SubjectsNotifier {
  final List<Map<String, dynamic>> _initial;
  _MockSubjectsNotifier(this._initial);
  @override
  List<Map<String, dynamic>> build() => _initial;
  @override
  Future<void> reload() async {}
}

class _MockSectionsNotifier extends SectionsNotifier {
  final List<Map<String, dynamic>> _initial;
  _MockSectionsNotifier(this._initial);
  @override
  List<Map<String, dynamic>> build() => _initial;
  @override
  Future<void> reload() async {}
}

class _MockAuthNotifier extends AuthNotifier {
  final User? _user;
  _MockAuthNotifier(this._user);
  @override
  User? build() => _user;
}

void main() {
  group('AiraSearchPickerModal Widget & Unit Tests', () {
    testWidgets('1. Filters items across title, subtitle, and searchKeywords', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedValue = await AiraSearchPickerModal.show<String>(
                    context: context,
                    title: 'Select Section',
                    searchHint: 'Search sections...',
                    items: const [
                      AiraSearchPickerItem(
                        value: 'stem_12a',
                        title: 'Grade 12 - STEM A',
                        subtitle: 'Grade 12 • 40 Students',
                        searchKeywords: ['stem', 'science'],
                      ),
                      AiraSearchPickerItem(
                        value: 'abm_12a',
                        title: 'Grade 12 - ABM A',
                        subtitle: 'Grade 12 • 38 Students',
                        searchKeywords: ['abm', 'business'],
                      ),
                      AiraSearchPickerItem(
                        value: 'g10_emerald',
                        title: 'Grade 10 - Emerald',
                        subtitle: 'Grade 10 • 45 Students',
                        searchKeywords: ['emerald', 'junior high'],
                      ),
                    ],
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Select Section'), findsOneWidget);
      expect(find.text('Grade 12 - STEM A'), findsOneWidget);
      expect(find.text('Grade 12 - ABM A'), findsOneWidget);
      expect(find.text('Grade 10 - Emerald'), findsOneWidget);
      expect(find.text('Available (3)'), findsOneWidget);

      // Search by keyword "business"
      await tester.enterText(find.byType(TextField), 'business');
      await tester.pumpAndSettle();

      expect(find.text('Grade 12 - ABM A'), findsOneWidget);
      expect(find.text('Grade 12 - STEM A'), findsNothing);
      expect(find.text('Grade 10 - Emerald'), findsNothing);
      expect(find.text('Available (1)'), findsOneWidget);

      // Tap the filtered item
      await tester.tap(find.text('Grade 12 - ABM A'));
      await tester.pumpAndSettle();

      // Dialog closed and value returned
      expect(selectedValue, 'abm_12a');
    });

    testWidgets('2. Shows empty state when no query matches and clears query with button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AiraSearchPickerModal.show<String>(
                  context: context,
                  title: 'Select Instructor',
                  searchHint: 'Search instructor...',
                  items: const [
                    AiraSearchPickerItem(value: 't1', title: 'Dr. John Watson'),
                  ],
                ),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Enter query with no match
      await tester.enterText(find.byType(TextField), 'Sherlock');
      await tester.pumpAndSettle();

      expect(find.text('No matches for "Sherlock"'), findsOneWidget);
      expect(find.text('Available (0)'), findsOneWidget);

      // Tap clear suffix icon
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Dr. John Watson'), findsOneWidget);
      expect(find.text('Available (1)'), findsOneWidget);
    });
  });

  group('CreateEditScheduleDialog Searchable Inputs Tests', () {
    testWidgets('3. Renders Faculty, Subject, and Section as searchable picker selectors', (tester) async {
      final mockAdmin = User(
        id: 'admin_1',
        email: 'admin@aira.edu',
        fullName: 'Admin User',
        role: 'admin',
      );

      final teachers = [
        {'id': 'tea_1', 'full_name': 'Prof. Alan Turing', 'email': 'alan@aira.edu', 'department': 'Computer Science'},
        {'id': 'tea_2', 'full_name': 'Prof. Ada Lovelace', 'email': 'ada@aira.edu', 'department': 'Software Engineering'},
      ];

      final subjects = [
        {'id': 201, 'name': 'Mobile UI & State Management', 'subject_code': 'CS202', 'description': 'Flutter & Dart'},
        {'id': 202, 'name': 'Database Systems', 'subject_code': 'CS301', 'description': 'SQL & NoSQL'},
      ];

      final sections = [
        {'id': 10, 'name': 'Grade 12 - Sapphire', 'grade': '12', 'room': 'Room 401', 'student_count': 32},
        {'id': 11, 'name': 'Grade 12 - Ruby', 'grade': '12', 'room': 'Room 402', 'student_count': 30},
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(mockAdmin)),
            adminTeachersProvider.overrideWith(() => _MockAdminTeachersNotifier(teachers)),
            subjectsProvider.overrideWith(() => _MockSubjectsNotifier(subjects)),
            sectionsProvider.overrideWith(() => _MockSectionsNotifier(sections)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateEditScheduleDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & labels
      expect(find.text('Assign Class Schedule'), findsOneWidget);
      expect(find.text('Assigned Faculty / Instructor *'), findsOneWidget);
      expect(find.text('Class Subject *'), findsOneWidget);
      expect(find.text('Class Section *'), findsOneWidget);

      // Verify search icon badges on the selectors
      expect(find.byIcon(Icons.search_rounded), findsNWidgets(3));

      // Test opening subject search modal
      await tester.tap(find.textContaining('CS202 - Mobile UI & State Management'));
      await tester.pumpAndSettle();

      expect(find.text('Select Class Subject'), findsOneWidget);
      expect(find.textContaining('CS301 - Database Systems'), findsOneWidget);

      // Search subject by code "301"
      await tester.enterText(find.byType(TextField).last, '301');
      await tester.pumpAndSettle();

      expect(find.textContaining('CS301 - Database Systems'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AiraSearchPickerModal<int>),
          matching: find.textContaining('CS202 - Mobile UI & State Management'),
        ),
        findsNothing,
      );

      // Select CS301
      await tester.tap(find.textContaining('CS301 - Database Systems'));
      await tester.pumpAndSettle();

      // Modal closed, field updated
      expect(find.text('Select Class Subject'), findsNothing);
      expect(find.textContaining('CS301 - Database Systems'), findsOneWidget);
    });
  });
}
