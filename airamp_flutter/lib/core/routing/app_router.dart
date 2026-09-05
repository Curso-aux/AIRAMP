import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/student/presentation/student_layout_screen.dart';
import '../../features/student/presentation/student_dashboard_screen.dart';
import '../../features/student/presentation/student_courses_screen.dart';
import '../../features/student/presentation/student_progress_screen.dart';
import '../../features/student/presentation/student_history_screen.dart';
import '../../features/student/presentation/student_chat_screen.dart';
import '../../features/student/presentation/student_profile_screen.dart';
import '../../features/admin/presentation/admin_layout_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_subjects_screen.dart';
import '../../features/admin/presentation/admin_students_screen.dart';
import '../../features/admin/presentation/admin_chat_screen.dart';
import '../../features/admin/presentation/admin_profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Center(child: Text('Home')))),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudentLayoutScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/student', builder: (context, state) => const StudentDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/courses', builder: (context, state) => const StudentCoursesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/progress', builder: (context, state) => const StudentProgressScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/history', builder: (context, state) => const StudentHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/chat', builder: (context, state) => const StudentChatScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/profile', builder: (context, state) => const StudentProfileScreen())]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminLayoutScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/subjects', builder: (context, state) => const AdminSubjectsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/students', builder: (context, state) => const AdminStudentsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/chat', builder: (context, state) => const AdminChatScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/profile', builder: (context, state) => const AdminProfileScreen())]),
        ],
      ),
    ],
  );
}
