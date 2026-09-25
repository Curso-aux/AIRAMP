import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_home_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_scaffold.dart';
import 'package:airamp_flutter/src/features/student/data/student_repository.dart';
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
      'due_date': '2026-09-29T17:13:10.383563',
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
            StatefulShellBranch(routes: [GoRoute(path: '/student/progress', builder: (context, state) => const SizedBox())]),
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
    await tester.pumpAndSettle();

    // Verify exactly 5 bottom navigation items: Dashboard, Courses, Progress, Quizzes, Chat
    final navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(navBar.items.length, 5);
    expect(navBar.items.map((i) => i.label).toList(), ['Dashboard', 'Courses', 'Progress', 'Quizzes', 'Chat']);

    // Profile should NOT be on the bottom bar
    expect(navBar.items.any((i) => i.label == 'Profile'), isFalse);
  });
}
