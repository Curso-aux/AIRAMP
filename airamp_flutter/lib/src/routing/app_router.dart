import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/landing/presentation/web_landing_screen.dart';
import '../features/auth/presentation/web/admin_web_login_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/admin_signup_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/application/auth_provider.dart';
import '../features/student/presentation/student_home_screen.dart';
import '../features/student/presentation/my_courses_screen.dart';
import '../features/student/presentation/student_course_detail_screen.dart';
import '../features/student/presentation/my_progress_screen.dart';
import '../features/student/presentation/quiz_history_screen.dart';
import '../features/student/presentation/student_profile_screen.dart';
import '../features/admin/presentation/subjects_mgmt_screen.dart';
import '../features/admin/presentation/subject_detail_screen.dart';
import '../features/admin/presentation/sections_mgmt_screen.dart';
import '../features/admin/presentation/scores_screen.dart';
import '../features/admin/presentation/admin_management_screen.dart';
import '../features/admin/presentation/web/admin_web_scaffold.dart';
import '../features/admin/presentation/web/admin_web_analytics_view.dart';
import '../features/admin/presentation/web/admin_web_students_screen.dart';
import '../features/admin/presentation/web/admin_web_teachers_screen.dart';
import '../features/admin/presentation/web/admin_web_keys_screen.dart';
import '../features/admin/presentation/web/admin_web_announcements_screen.dart';
import '../features/student/presentation/student_scaffold.dart';
import '../features/teacher/presentation/teacher_scaffold.dart';
import '../features/teacher/presentation/teacher_dashboard_screen.dart';
import '../features/teacher/presentation/teacher_students_screen.dart';
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

  final initialLoc = (authState != null && (authState.role == 'admin' || authState.role == 'super_admin'))
      ? '/admin/dashboard'
      : (authState != null && authState.role == 'teacher'
          ? '/teacher/dashboard'
          : (authState != null && !kIsWeb
              ? '/student/home'
              : (kIsWeb ? '/' : '/login')));

  return GoRouter(
    initialLocation: initialLoc,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => kIsWeb ? const WebLandingScreen() : const LoginScreen(),
      ),
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminWebLoginScreen(),
      ),
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
      // Teacher Routes with Bottom Navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TeacherScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/dashboard',
                builder: (context, state) => const TeacherDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/subjects',
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
                path: '/teacher/scores',
                builder: (context, state) => const ScoresScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/students',
                builder: (context, state) {
                  final initialSection = state.uri.queryParameters['section'];
                  return TeacherStudentsScreen(initialSection: initialSection);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/chat',
                builder: (context, state) => const ChatListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/profile',
                builder: (context, state) => const StudentProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Admin Web Portal Routes with Responsive Sidebar Scaffold
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminWebScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/dashboard',
                builder: (context, state) => const AdminWebAnalyticsView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/students',
                builder: (context, state) => const AdminWebStudentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/teachers',
                builder: (context, state) => const AdminWebTeachersScreen(),
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
                path: '/admin/keys',
                builder: (context, state) => const AdminWebKeysScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/announcements',
                builder: (context, state) => const AdminWebAnnouncementsScreen(),
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
                path: '/admin/sections',
                builder: (context, state) => const SectionsMgmtScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/reg-links',
        builder: (context, state) => const AdminWebKeysScreen(),
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
        path: '/student/course/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return StudentCourseDetailScreen(courseId: id);
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
      final matched = state.matchedLocation;
      final isPublicRoute = matched == '/' ||
          matched == '/login' ||
          matched == '/admin/login' ||
          matched == '/signup' ||
          matched == '/admin-signup' ||
          matched == '/forgot-password';

      // Strict Platform Separation Guard:
      // On Mobile / Desktop (!kIsWeb): Admin is strictly forbidden. Mobile is ONLY for Students and Teachers!
      if (!kIsWeb) {
        if (isAuth && (authState.role == 'admin' || authState.role == 'super_admin')) {
          return '/login';
        }
        if (matched.startsWith('/admin')) {
          return '/login';
        }
      }

      // 1. Unauthenticated user trying to access protected route
      if (!isAuth && !isPublicRoute) {
        if (kIsWeb && matched.startsWith('/admin')) {
          return '/admin/login';
        }
        return kIsWeb ? '/' : '/login';
      }

      // 2. On Web, visiting generic /login routes to /admin/login
      if (kIsWeb && matched == '/login') {
        if (!isAuth) return '/admin/login';
        if (authState.role == 'admin' || authState.role == 'super_admin') {
          return '/admin/dashboard';
        }
        return '/';
      }

      // 3. Authenticated user visiting landing page '/' or login routes
      if (isAuth) {
        final isAdmin = authState.role == 'admin' || authState.role == 'super_admin';
        final isTeacher = authState.role == 'teacher';

        // When authenticated, visiting '/' automatically routes to the appropriate portal
        if (matched == '/') {
          if (isAdmin) {
            return '/admin/dashboard';
          } else if (isTeacher) {
            return '/teacher/dashboard';
          } else if (!kIsWeb) {
            return '/student/home';
          }
        }

        final isLoginRoute = matched == '/login' ||
            matched == '/admin/login' ||
            matched == '/signup' ||
            matched == '/admin-signup' ||
            matched == '/forgot-password';

        if (isLoginRoute) {
          if (isAdmin) {
            return kIsWeb ? '/admin/dashboard' : '/login';
          } else if (isTeacher) {
            return '/teacher/dashboard';
          } else {
            return kIsWeb ? '/' : '/student/home';
          }
        }
      }

      // 4. Role-based Route Guard
      if (isAuth) {
        final isAdmin = authState.role == 'admin' || authState.role == 'super_admin';
        final isTeacher = authState.role == 'teacher';
        final isStudent = authState.role == 'student';

        if (isAdmin && (matched.startsWith('/student') || matched.startsWith('/teacher'))) {
          return kIsWeb ? '/admin/dashboard' : '/login';
        }

        if (!isAdmin && matched.startsWith('/admin') && matched != '/admin/login') {
          return isTeacher ? '/teacher/dashboard' : (kIsWeb ? '/admin/login' : '/student/home');
        }

        if (isStudent && matched.startsWith('/teacher')) {
          return '/student/home';
        }

        if (isTeacher && matched.startsWith('/student') && !matched.startsWith('/student/course')) {
          return '/teacher/dashboard';
        }
      }

      return null; // No redirect needed
    },
  );
});
