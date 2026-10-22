import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/components/animated_curved_nav_bar.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_home_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_schedule_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_sticky_top_header.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_scaffold.dart';
import 'package:airamp_flutter/src/features/student/data/student_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/halftone_pattern.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

class _MockAuthNotifier extends AuthNotifier {
  @override
  User? build() {
    return User(id: 'student_1', email: 'maria@school.edu', role: 'student', fullName: 'Maria Lopez', section: 'Grade 10 - Emerald');
  }
}

class _MockQuizAssignmentsNotifier extends StudentQuizAssignmentsNotifier {
  final List<Map<String, dynamic>> _quizzes;
  _MockQuizAssignmentsNotifier(this._quizzes);

  @override
  List<Map<String, dynamic>> build() => _quizzes;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sampleQuizzes = [
    {
      'quiz_id': 1,
      'title': 'Midterm Quiz',
      'subject_code': 'CS202',
      'teacher_name': 'Sir John Reyes',
      'question_count': 3,
      'time_limit_minutes': 60,
      'due_date': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'status': 'pending',
    },
    {
      'quiz_id': 2,
      'title': 'Past Quiz',
      'subject_code': 'CS101',
      'teacher_name': 'Sir John Reyes',
      'question_count': 3,
      'time_limit_minutes': 15,
      'due_date': '2026-09-17T00:47:34.294492',
      'status': 'pending',
    },
  ];

  testWidgets('1. Due date formatting converts raw ISO string to human-readable badge without microseconds', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier()),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizAssignmentsNotifier(sampleQuizzes)),
        ],
        child: const MaterialApp(home: Scaffold(body: StudentHomeScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Raw unformatted ISO timestamp with microseconds should NEVER appear
    expect(find.textContaining('.383563'), findsNothing);
    expect(find.textContaining('.294492'), findsNothing);

    // Formatted readable badges should appear
    expect(find.textContaining('Due in'), findsOneWidget);
    expect(find.textContaining('Overdue (Sep 17)'), findsOneWidget);
  });

  testWidgets('2. Redundant "Teacher Class Schedules" banner is removed, avoiding duplicate schedule blocks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier()),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizAssignmentsNotifier([])),
        ],
        child: const MaterialApp(home: Scaffold(body: StudentHomeScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // The old duplicate banner text should NOT exist
    expect(find.text('Teacher Class Schedules'), findsNothing);
    expect(find.textContaining('Tap to view weekly timetable'), findsNothing);

    // The genuine Class Schedule widget is present
    expect(find.text('Class Schedule'), findsOneWidget);
  });

  testWidgets('3. StudentScaffold has 5 spacious tabs without bottom nav Profile clutter', (tester) async {
    final router = GoRouter(
      initialLocation: '/student/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return StudentScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/student/home', builder: (context, state) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/student/courses', builder: (context, state) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/student/schedule', builder: (context, state) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/student/quiz-history', builder: (context, state) => const SizedBox())]),
            StatefulShellBranch(routes: [GoRoute(path: '/student/chat', builder: (context, state) => const SizedBox())]),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Verify exactly 5 bottom navigation items: Dashboard, Courses, Calendar (in the middle!), Quizzes, Chat
    final navBar = tester.widget<AnimatedCurvedNavBar>(find.byType(AnimatedCurvedNavBar));
    expect(navBar.items.length, 5);
    expect(navBar.items.map((i) => i.label).toList(), ['Dashboard', 'Courses', 'Calendar', 'Quizzes', 'Chat']);

    // Profile should NOT be on the bottom bar
    expect(navBar.items.any((i) => i.label == 'Profile'), isFalse);
  });

  testWidgets('4. Dashboard top header contains student identity, materials & bell, and NO calendar icon', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier()),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizAssignmentsNotifier([])),
        ],
        child: const MaterialApp(home: Scaffold(body: StudentHomeScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // Verify StudentStickyTopHeader is present
    expect(find.byType(StudentStickyTopHeader), findsOneWidget);

    // Verify Student Identity details
    expect(find.text('Maria Lopez'), findsOneWidget);
    expect(find.text('STUDENT'), findsOneWidget);
    expect(find.text('Grade 10 - Emerald'), findsWidgets);

    // Verify Offline Materials and Notifications Bell exist inside the header
    expect(find.byTooltip('Saved Offline Materials (0)'), findsOneWidget);
    expect(find.byTooltip('Announcements & Notifications'), findsOneWidget);

    // Verify Calendar icon button is REMOVED from the sticky top header
    expect(find.byTooltip('View Class Timetable & Schedules'), findsNothing);
  });

  testWidgets('5. Calendar tab (StudentScheduleScreen) renders Timetable Grid with Halftone with color and no profile header', (tester) async {
    final sampleSchedules = [
      {
        'id': 'sched_1',
        'subject_name': 'CSS NC II - Computer Systems',
        'teacher_name': 'Sir John Reyes',
        'room': 'Computer Lab 1',
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Thursday',
        'start_time': '08:00',
        'end_time': '09:30',
        'color_code': '#EC4899',
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier()),
          sectionSchedulesProvider('Grade 10 - Emerald').overrideWith((ref) async => sampleSchedules),
        ],
        child: const MaterialApp(home: Scaffold(body: StudentScheduleScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // 1. Verify StudentStickyTopHeader (profile card) is NOT present on Calendar tab
    expect(find.byType(StudentStickyTopHeader), findsNothing);

    // 2. Verify dedicated Screen Header with Timetable Grid & section badge (matching Picture 1)
    expect(find.text('Timetable Grid'), findsOneWidget);
    expect(find.text('Weekly section matrix & room locations'), findsOneWidget);
    expect(find.text('Grade 10 - Emerald'), findsWidgets);

    // 3. Verify anchored View Switchers (Calendar, Grid, Agenda)
    expect(find.byTooltip('Calendar View'), findsOneWidget);
    expect(find.byTooltip('Timetable Grid'), findsOneWidget);
    expect(find.byTooltip('Agenda View'), findsOneWidget);

    // 4. Verify Timetable Grid matrix elements: TIME column & subject block with Halftone pattern
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('CSS NC II - Computer Systems'), findsOneWidget);
    expect(find.text('Computer Lab 1'), findsOneWidget);
    expect(find.byType(HalftoneCardDecoration), findsWidgets);

    // Verify Day Filter Row has sleek, proportional check (size 13) and no bulky CircleAvatar
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Tue'), findsOneWidget);
    final activeCheckIcon = tester.widget<Icon>(find.byIcon(Icons.check_rounded).first);
    expect(activeCheckIcon.size, 13.0);
    expect(find.byType(CircleAvatar), findsNothing);

    // 5. Switch to Agenda View to verify detailed schedule cards matching Picture 2
    await tester.tap(find.byTooltip('Agenda View'));
    await tester.pumpAndSettle();

    expect(find.text('Thursday'), findsWidgets);
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('to 9:30 AM'), findsOneWidget);
    expect(find.text('Assigned'), findsOneWidget);
    expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);

    // 6. Tap on schedule card in Agenda view to verify institutional class detail modal
    await tester.tap(find.text('CSS NC II - Computer Systems').first);
    await tester.pumpAndSettle();

    // Verify Institutional Modal Architecture & Elements (Monochromatic Slate, no videogame rainbow colors)
    expect(find.text('CLASS PERIOD'), findsOneWidget);
    expect(find.text('FACULTY / INSTRUCTOR'), findsOneWidget);
    expect(find.text('CAMPUS FACILITY & ROOM'), findsOneWidget);
    expect(find.text('ASSIGNED SECTION'), findsOneWidget);
    expect(find.text('Official Class'), findsOneWidget);
    expect(find.text('Close Overview'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    final closeBtn = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Close Overview'));
    expect(closeBtn.style?.backgroundColor?.resolve({}), const Color(0xFF0F172A));

    // Tap Close Overview to verify smooth dismiss
    await tester.tap(find.text('Close Overview'));
    await tester.pumpAndSettle();
    expect(find.text('Close Overview'), findsNothing);
  });
}

