import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_profile_screen.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _user;
  MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class _FakeTeacherSubjectsNotifier extends TeacherSubjectsNotifier {
  final List<Map<String, dynamic>> subjects;
  _FakeTeacherSubjectsNotifier(this.subjects);

  @override
  List<Map<String, dynamic>> build() => subjects;

  @override
  Future<void> reload() async {}
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

  final dummyTeacher = User(
    id: 'tch_001',
    email: 'poblacion197@gmail.com',
    role: 'teacher',
    fullName: 'Jhoneil L. Poblacion',
    username: 'jhoneil',
    section: 'Grade 10 - Rizal',
    schoolId: 'sch_deped_main',
    mustChangePassword: false,
  );

  final dummySubjects = [
    {
      'id': 1,
      'name': 'Science & Technology 10',
      'subject_code': 'SCI-10',
      'semester': '1st Semester',
    },
    {
      'id': 2,
      'name': 'Mathematics 10',
      'subject_code': 'MATH-10',
      'semester': '1st Semester',
    },
  ];

  final dummySections = ['Grade 10 - Rizal', 'Grade 10 - Bonifacio'];

  final dummySectionDetails = [
    {
      'name': 'Grade 10 - Rizal',
      'room': 'Rm 204',
      'studentCount': 34,
      'grade': '10',
    },
    {
      'name': 'Grade 10 - Bonifacio',
      'room': 'Rm 205',
      'studentCount': 32,
      'grade': '10',
    },
  ];

  final dummyStudents = [
    {'id': 'st_1', 'name': 'Juan Dela Cruz'},
    {'id': 'st_2', 'name': 'Maria Clara'},
    {'id': 'st_3', 'name': 'Crisostomo Ibarra'},
  ];

  final dummySchedules = [
    {'id': 1, 'subject': 'Science 10', 'day_of_week': 'Monday'},
    {'id': 2, 'subject': 'Mathematics 10', 'day_of_week': 'Tuesday'},
    {'id': 3, 'subject': 'Science 10', 'day_of_week': 'Wednesday'},
  ];

  Widget createTestWidget() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TeacherProfileScreen(),
        ),
        GoRoute(
          path: '/teacher/subjects',
          builder: (context, state) => const Scaffold(body: Text('Subjects Screen')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => const Scaffold(body: Text('Subject Detail Screen')),
            ),
          ],
        ),
        GoRoute(
          path: '/teacher/dashboard',
          builder: (context, state) => const Scaffold(body: Text('Dashboard Screen')),
        ),
        GoRoute(
          path: '/teacher/students',
          builder: (context, state) => const Scaffold(body: Text('Students Screen')),
        ),
        GoRoute(
          path: '/teacher/schedule',
          builder: (context, state) => const Scaffold(body: Text('Schedule Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authProvider.overrideWith(() => MockAuthNotifier(dummyTeacher)),
        teacherSubjectsProvider.overrideWith(() => _FakeTeacherSubjectsNotifier(dummySubjects)),
        teacherHandledSectionsProvider.overrideWith((ref) async => dummySections),
        teacherHandledSectionsDetailsProvider.overrideWith((ref) async => dummySectionDetails),
        teacherStudentsProvider.overrideWith(() => _FakeTeacherStudentsNotifier(dummyStudents)),
        teacherSchedulesProvider.overrideWith(() => _FakeTeacherScheduleNotifier(dummySchedules)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('Teacher Profile & Settings renders complete, useful faculty command center', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // 1. Header Bar
    expect(find.text('Faculty Profile & Settings'), findsOneWidget);
    expect(find.text('Active Faculty'), findsNothing);

    // 2. Hero Faculty Identity Card
    expect(find.text('Jhoneil L. Poblacion'), findsNWidgets(2));
    expect(find.text('@jhoneil'), findsOneWidget);
    expect(find.text('Teacher / Faculty'), findsOneWidget);
    expect(find.text('DepEd Verified'), findsOneWidget);
    expect(find.text('Adviser: Grade 10 - Rizal'), findsOneWidget);

    // 3. Workload KPIs
    expect(find.text('Subjects'), findsOneWidget);
    expect(find.text('Sections'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Classes'), findsOneWidget);

    // 4. Academic Portfolio
    expect(find.text('Academic Portfolio'), findsOneWidget);
    expect(find.text('Science & Technology 10'), findsOneWidget);
    expect(find.text('Mathematics 10'), findsOneWidget);
    expect(find.text('Grade 10 - Rizal'), findsWidgets);

    // Offline Station & Mesh removed from profile
    expect(find.text('Offline Station & Mesh'), findsNothing);
    expect(find.text('Station Hub'), findsNothing);

    // 5. Personal & Institutional Information
    expect(find.text('Personal & Institutional Info'), findsOneWidget);
    expect(find.text('poblacion197@gmail.com'), findsOneWidget);
    expect(find.text('Advisory Section'), findsOneWidget);
    expect(find.text('sch_deped_main'), findsOneWidget);
    expect(find.text('Faculty / Educator (Level 2 Access)'), findsOneWidget);

    // 6. Preferences Card
    expect(find.text('Classroom Preferences'), findsOneWidget);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Quiz Submissions Alert'), findsOneWidget);
    expect(find.text('Class Schedule Reminders'), findsOneWidget);
    expect(find.text('Haptic Touch Feedback'), findsOneWidget);

    // 7. Institutional Support & Compliance
    expect(find.text('Institutional Support & Info'), findsOneWidget);
    expect(find.text('AIRAMP DepEd Classroom Suite'), findsOneWidget);
    expect(find.text('v1.4.0 (Build 2026.10)'), findsOneWidget);
    expect(find.text('SQLite 3.45 + Local Mesh Client'), findsOneWidget);
    expect(find.text('Faculty Quick Help & Offline Guide'), findsOneWidget);
    expect(find.text('Data Privacy & DepEd Compliance'), findsOneWidget);

    // 8. Sign Out Button & Subtitle
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('End current faculty session safely'), findsOneWidget);
  });

  testWidgets('Faculty Quick Help & Privacy Dialogs open smoothly when tapped', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Scroll to Support section
    await tester.scrollUntilVisible(
      find.text('Faculty Quick Help & Offline Guide'),
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap Faculty Quick Help
    await tester.tap(find.text('Faculty Quick Help & Offline Guide'));
    await tester.pumpAndSettle();

    // Verify dialog contents
    expect(find.text('Faculty User Guide'), findsOneWidget);
    expect(find.text('Offline Quiz Submissions'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Tap Privacy dialog
    await tester.tap(find.text('Data Privacy & DepEd Compliance'));
    await tester.pumpAndSettle();

    expect(find.text('Data Privacy & Compliance'), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();
  });

  testWidgets('Tapping Return Back button reliably navigates back or falls back to Dashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    final backBtn = find.byTooltip('Back to Dashboard');
    expect(backBtn, findsOneWidget);

    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Screen'), findsOneWidget);
  });

  testWidgets('Tapping Sign Out button displays the modern confirmation dialog and dismisses on Cancel', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Scroll until Sign Out button is visible
    await tester.scrollUntilVisible(
      find.text('End current faculty session safely'),
      500.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap the Sign Out card
    await tester.tap(find.text('End current faculty session safely'));
    await tester.pumpAndSettle();

    // Verify confirmation modal content
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text('Are you sure you want to sign out? Your offline classroom records and cache will remain safely stored on this device.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss with Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
  });
}
