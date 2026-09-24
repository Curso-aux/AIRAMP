import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_dashboard_screen.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _user;
  MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class _FakeTeacherDashboardNotifier extends TeacherDashboardNotifier {
  final Map<String, dynamic> initialStats;
  _FakeTeacherDashboardNotifier(this.initialStats);

  @override
  Map<String, dynamic> build() => initialStats;

  @override
  Future<void> reload({String? section, String? studentId, bool resetFilters = false}) async {
    final isStudentFilter = studentId != null && studentId != 'All';
    final isSectionFilter = section != null && section != 'All Handled Sections';

    state = {
      'totalSubjects': isSectionFilter ? 2 : 5,
      'totalStudents': isStudentFilter ? 1 : (isSectionFilter ? 2 : 5),
      'totalAttempts': isStudentFilter ? 2 : (isSectionFilter ? 5 : 3),
      'passedAttempts': isStudentFilter ? 2 : (isSectionFilter ? 4 : 1),
      'passRate': isStudentFilter ? 100 : (isSectionFilter ? 80 : 33),
      'avgScore': isStudentFilter ? 95 : (isSectionFilter ? 85 : 33),
      'recentAttempts': <Map<String, dynamic>>[],
    };
  }
}

class _FakeTeacherStudentsNotifier extends TeacherStudentsNotifier {
  final List<Map<String, dynamic>> students;
  _FakeTeacherStudentsNotifier(this.students);

  @override
  List<Map<String, dynamic>> build() => students;
}

class _FakeTeacherScheduleNotifier extends TeacherScheduleNotifier {
  final List<Map<String, dynamic>> schedules;
  _FakeTeacherScheduleNotifier(this.schedules);

  @override
  List<Map<String, dynamic>> build() => schedules;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sampleTeacher = User(
    id: 'teacher_1',
    email: 'teacher@school.edu',
    fullName: 'Sir John Reyes',
    role: 'teacher',
  );

  final sampleStudents = [
    {'id': 'std_1', 'full_name': 'Juan Dela Cruz', 'section': 'STEM 12-A'},
    {'id': 'std_2', 'full_name': 'Maria Santos', 'section': 'STEM 12-A'},
    {'id': 'std_3', 'full_name': 'Pedro Penduko', 'section': 'STEM 12-B'},
  ];

  final sampleSchedules = [
    {
      'id': 1,
      'subject_id': 101,
      'subject_name': 'General Mathematics',
      'section': 'STEM 12-A',
      'day_of_week': 'Monday',
      'start_time': '08:00',
      'end_time': '09:30',
      'room': 'Room 302',
      'color': '#0D9488',
    },
    {
      'id': 2,
      'subject_id': 102,
      'subject_name': 'Earth & Life Science',
      'section': 'STEM 12-B',
      'day_of_week': 'Monday',
      'start_time': '10:00',
      'end_time': '11:30',
      'room': 'Science Lab 1',
      'color': '#2563EB',
    },
  ];

  final defaultStats = {
    'totalSubjects': 5,
    'totalStudents': 5,
    'totalAttempts': 3,
    'passedAttempts': 1,
    'passRate': 33,
    'avgScore': 33,
    'recentAttempts': <Map<String, dynamic>>[],
  };

  group('Teacher Dashboard Collapsible & Filterable Analytics Tests', () {
    testWidgets('1. Analytics is collapsed by default and shows compact banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherDashboardProvider.overrideWith(() => _FakeTeacherDashboardNotifier(defaultStats)),
            teacherStudentsProvider.overrideWith(() => _FakeTeacherStudentsNotifier(sampleStudents)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
            teacherHandledSectionsDetailsProvider.overrideWith((ref) async => []),
            teacherSubjectsProvider.overrideWith(() => TeacherSubjectsNotifier()),
          ],
          child: const MaterialApp(
            home: TeacherDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Compact banner should be visible
      expect(find.text('Performance & Analytics'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('33% Pass Rate'), findsOneWidget);

      // The 4 KPI cards and dropdowns should NOT be visible when collapsed
      expect(find.text('Class Pass Rate'), findsNothing);
      expect(find.text('Average Score'), findsNothing);
      expect(find.text('Assigned Subjects'), findsNothing);
    });

    testWidgets('2. Tapping Show button expands analytics revealing filters and KPI metric cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherDashboardProvider.overrideWith(() => _FakeTeacherDashboardNotifier(defaultStats)),
            teacherStudentsProvider.overrideWith(() => _FakeTeacherStudentsNotifier(sampleStudents)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
            teacherHandledSectionsDetailsProvider.overrideWith((ref) async => []),
            teacherSubjectsProvider.overrideWith(() => TeacherSubjectsNotifier()),
          ],
          child: const MaterialApp(
            home: TeacherDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Show" to expand analytics
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Header should show "Hide" button
      expect(find.text('Hide'), findsOneWidget);

      // Dropdowns should be present
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.text('All Students'), findsOneWidget);

      // All 4 KPI metric cards should now be rendered
      expect(find.text('Class Pass Rate'), findsOneWidget);
      expect(find.text('Average Score'), findsOneWidget);
      expect(find.text('Assigned Subjects'), findsOneWidget);
      expect(find.text('Enrolled Students'), findsOneWidget);

      // Tapping "Hide" collapses the card back down
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();

      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Class Pass Rate'), findsNothing);
    });

    testWidgets('3. Selecting a section filter cascades to available students and updates metrics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherDashboardProvider.overrideWith(() => _FakeTeacherDashboardNotifier(defaultStats)),
            teacherStudentsProvider.overrideWith(() => _FakeTeacherStudentsNotifier(sampleStudents)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
            teacherHandledSectionsDetailsProvider.overrideWith((ref) async => []),
            teacherSubjectsProvider.overrideWith(() => TeacherSubjectsNotifier()),
          ],
          child: const MaterialApp(
            home: TeacherDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand analytics
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Open Section dropdown
      await tester.tap(find.text('All Sections'));
      await tester.pumpAndSettle();

      // Select 'STEM 12-A'
      await tester.tap(find.text('STEM 12-A').last);
      await tester.pumpAndSettle();

      // Reset button should now appear
      expect(find.byTooltip('Reset Analytics Filter'), findsOneWidget);
      expect(find.text('Showing stats for: '), findsOneWidget);

      // Tap reset button to return to all
      await tester.tap(find.byTooltip('Reset Analytics Filter'));
      await tester.pumpAndSettle();

      expect(find.text('All Sections'), findsOneWidget);
      expect(find.byTooltip('Reset Analytics Filter'), findsNothing);
    });
  });

  group('Teacher Schedule Agenda View Overflow Fix Regression Tests', () {
    testWidgets('4. Schedule agenda list view renders without RenderFlex overflow on narrow 360px viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      FlutterErrorDetails? errorDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
        // ignore: avoid_print
        print('EXACT OVERFLOW ERROR: ${details.summary}');
        // ignore: avoid_print
        print('ERROR CONTEXT: ${details.context}');
        for (final d in details.informationCollector?.call() ?? []) {
          // ignore: avoid_print
          print('INFO: $d');
        }
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherSchedulesProvider.overrideWith(() => _FakeTeacherScheduleNotifier(sampleSchedules)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
          ],
          child: const MaterialApp(
            home: TeacherScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Agenda / List view (Icons.view_agenda_outlined)
      final agendaToggle = find.byIcon(Icons.view_agenda_outlined);
      expect(agendaToggle, findsOneWidget);
      await tester.tap(agendaToggle);
      await tester.pumpAndSettle();

      // Both classes should be rendered
      expect(find.text('General Mathematics'), findsOneWidget);
      expect(find.text('Earth & Life Science'), findsOneWidget);

      expect(errorDetails, isNull);
    });
  });
}
