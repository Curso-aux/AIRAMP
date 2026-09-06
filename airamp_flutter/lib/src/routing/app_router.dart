import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/admin_signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/student/presentation/student_home_screen.dart';
import '../features/student/presentation/my_courses_screen.dart';
import '../features/student/presentation/my_progress_screen.dart';
import '../features/student/presentation/quiz_history_screen.dart';
import '../features/student/presentation/student_profile_screen.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/admin/presentation/subjects_mgmt_screen.dart';
import '../features/admin/presentation/subject_detail_screen.dart';
import '../features/admin/presentation/sections_mgmt_screen.dart';
import '../features/admin/presentation/reg_links_screen.dart';
import '../features/admin/presentation/scores_screen.dart';
import '../features/admin/presentation/admin_profile_screen.dart';
import '../features/admin/presentation/admin_management_screen.dart';
import '../features/admin/presentation/admin_scaffold.dart';
import '../features/student/presentation/student_scaffold.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_room_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/submissions/presentation/submissions_screen.dart';

// Placeholder screens for unresolved domains
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/admin-signup',
        builder: (context, state) => const AdminSignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      // Student Routes with Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return StudentScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/home',
                builder: (context, state) => const StudentHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/courses',
                builder: (context, state) => const MyCoursesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/progress',
                builder: (context, state) => const MyProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/quiz-history',
                builder: (context, state) => const QuizHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/profile',
                builder: (context, state) => const StudentProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Admin Routes with Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/subjects',
                builder: (context, state) => const SubjectsMgmtScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return SubjectDetailScreen(subjectId: id);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/sections',
                builder: (context, state) => const SectionsMgmtScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/scores',
                builder: (context, state) => const ScoresScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/reg-links',
                builder: (context, state) => const RegLinksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/profile',
                builder: (context, state) => const AdminProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/admin-management',
        builder: (context, state) => const AdminManagementScreen(),
      ),
      // Shared Routes
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ChatRoomScreen(conversationId: id);
        },
      ),
      GoRoute(
        path: '/quiz/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuizScreen(quizId: id);
        },
      ),
      GoRoute(
        path: '/submissions/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SubmissionsScreen(assignmentId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final isAuth = authState != null;
      final isLoginRoute = state.matchedLocation == '/login' || 
                           state.matchedLocation == '/signup' || 
                           state.matchedLocation == '/admin-signup' || 
                           state.matchedLocation == '/forgot-password';

      if (!isAuth && !isLoginRoute) {
        // Redirect to login if not authenticated and trying to access protected route
        return '/login';
      }

      if (isAuth && isLoginRoute) {
        // Redirect away from login if already authenticated
        if (authState.role == 'admin' || authState.role == 'super_admin') {
          return '/admin/dashboard';
        } else {
          return '/student/home';
        }
      }

      // Role based guard
      if (isAuth) {
        final isAdmin = authState.role == 'admin' || authState.role == 'super_admin';
        final isStudent = authState.role == 'student';

        if (isAdmin && state.matchedLocation.startsWith('/student')) {
          return '/admin/dashboard';
        }

        if (isStudent && state.matchedLocation.startsWith('/admin')) {
          return '/student/home';
        }
      }

      return null; // No redirect needed
    },
  );
});
