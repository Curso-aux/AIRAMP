import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/animations/app_page_transitions.dart';
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
import '../features/admin/presentation/web/admin_web_schedule_screen.dart';
import '../features/student/presentation/student_scaffold.dart';
import '../features/teacher/presentation/teacher_scaffold.dart';
import '../features/teacher/presentation/teacher_dashboard_screen.dart';
import '../features/teacher/presentation/teacher_schedule_screen.dart';
import '../features/teacher/presentation/teacher_profile_screen.dart';
import '../features/teacher/presentation/teacher_students_screen.dart';
import '../features/teacher/presentation/teacher_subject_detail_screen.dart';
import '../features/chat/presentation/chat_list_screen.dart';
import '../features/chat/presentation/chat_room_screen.dart';
import '../features/quiz/presentation/quiz_screen.dart';
import '../features/quiz/presentation/module_gizmo_review_screen.dart';
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

/// A stable notifier bridge that notifies GoRouter on auth state changes
/// without re-instantiating the GoRouter instance itself.
class RouterAuthNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterAuthNotifier(this._ref) {
    _ref.listen<User?>(authProvider, (_, _) {
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = RouterAuthNotifier(ref);
  ref.onDispose(authNotifier.dispose);

  final initialAuth = ref.read(authProvider);
  final initialLoc = (initialAuth != null && (initialAuth.role == 'admin' || initialAuth.role == 'super_admin'))
      ? '/admin/dashboard'
      : (initialAuth != null && initialAuth.role == 'teacher'
          ? '/teacher/dashboard'
          : (initialAuth != null
              ? '/student/home'
              : (kIsWeb ? '/' : '/login')));

  return GoRouter(
    initialLocation: initialLoc,
    refreshListenable: authNotifier,
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: kIsWeb ? const WebLandingScreen() : const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/login',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: const AdminWebLoginScreen(initialRole: 'admin'),
        ),
      ),
      GoRoute(
        path: '/teacher/login',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: const AdminWebLoginScreen(initialRole: 'teacher'),
        ),
      ),
      GoRoute(
        path: '/student/login',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: const AdminWebLoginScreen(initialRole: 'student'),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final role = state.uri.queryParameters['role'] ?? 'unified';
          return AppPageTransitions.fadeThrough(
            key: state.pageKey,
            child: kIsWeb ? AdminWebLoginScreen(initialRole: role) : const LoginScreen(),
          );
        },
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/admin-signup',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const AdminSignupScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
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
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const StudentHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/courses',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const MyCoursesScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/progress',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const MyProgressScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/quiz-history',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const QuizHistoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/student/chat',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const ChatListScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/student/profile',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const StudentProfileScreen(),
        ),
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
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const TeacherDashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/subjects',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const SubjectsMgmtScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return AppPageTransitions.page(
                        key: state.pageKey,
                        child: TeacherSubjectDetailScreen(subjectId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/schedule',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const TeacherScheduleScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/students',
                pageBuilder: (context, state) {
                  final initialSection = state.uri.queryParameters['section'];
                  final tab = state.uri.queryParameters['tab'];
                  final initialTab = tab == 'scores' ? 1 : 0;
                  return AppPageTransitions.page(
                    key: state.pageKey,
                    child: TeacherStudentsScreen(
                      initialSection: initialSection,
                      initialTab: initialTab,
                    ),
                  );
                },
              ),
              GoRoute(
                path: '/teacher/scores',
                redirect: (context, state) => '/teacher/students?tab=scores',
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/teacher/chat',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const ChatListScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/teacher/profile',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const TeacherProfileScreen(),
        ),
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
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebAnalyticsView(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/students',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebStudentsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/teachers',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebTeachersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/subjects',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const SubjectsMgmtScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return AppPageTransitions.page(
                        key: state.pageKey,
                        child: SubjectDetailScreen(subjectId: id),
                      );
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
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebKeysScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/announcements',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebAnnouncementsScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/scores',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const ScoresScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/sections',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const SectionsMgmtScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin/schedules',
                pageBuilder: (context, state) => AppPageTransitions.page(
                  key: state.pageKey,
                  child: const AdminWebScheduleScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin/reg-links',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const AdminWebKeysScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/admin-management',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const AdminManagementScreen(),
        ),
      ),
      // Shared Routes & Activity Screens
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) => AppPageTransitions.page(
          key: state.pageKey,
          child: const ChatListScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppPageTransitions.page(
            key: state.pageKey,
            child: ChatRoomScreen(conversationId: id),
          );
        },
      ),
      GoRoute(
        path: '/student/course/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppPageTransitions.page(
            key: state.pageKey,
            child: StudentCourseDetailScreen(courseId: id),
          );
        },
      ),
      GoRoute(
        path: '/quiz/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppPageTransitions.activityModal(
            key: state.pageKey,
            child: QuizScreen(quizId: id),
          );
        },
      ),
      GoRoute(
        path: '/module-review/:loId',
        pageBuilder: (context, state) {
          final loId = int.tryParse(state.pathParameters['loId'] ?? '0') ?? 0;
          final title = state.uri.queryParameters['title'];
          final subject = state.uri.queryParameters['subject'];
          return AppPageTransitions.activityModal(
            key: state.pageKey,
            child: ModuleGizmoReviewScreen(
              loId: loId,
              initialModuleTitle: title,
              initialSubjectName: subject,
            ),
          );
        },
      ),
      GoRoute(
        path: '/submissions/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppPageTransitions.activityModal(
            key: state.pageKey,
            child: SubmissionsScreen(assignmentId: id),
          );
        },
      ),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState != null;
      final matched = state.matchedLocation;
      final isPublicRoute = matched == '/' ||
          matched == '/login' ||
          matched == '/admin/login' ||
          matched == '/teacher/login' ||
          matched == '/student/login' ||
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

      // 2. On Web, visiting generic login routes to appropriate portal
      if (kIsWeb && (matched == '/login' || matched == '/student/login' || matched == '/teacher/login')) {
        if (!isAuth) return null;
        if (authState.role == 'admin' || authState.role == 'super_admin') {
          return '/admin/dashboard';
        } else if (authState.role == 'teacher') {
          return '/teacher/dashboard';
        }
        return '/student/home';
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
          } else {
            return '/student/home';
          }
        }

        final isLoginRoute = matched == '/login' ||
            matched == '/admin/login' ||
            matched == '/teacher/login' ||
            matched == '/student/login' ||
            matched == '/signup' ||
            matched == '/admin-signup' ||
            matched == '/forgot-password';

        if (isLoginRoute) {
          if (isAdmin) {
            return '/admin/dashboard';
          } else if (isTeacher) {
            return '/teacher/dashboard';
          } else {
            return '/student/home';
          }
        }
      }

      // 4. Role-based Route Guard
      if (isAuth) {
        final isSuperAdmin = authState.role == 'super_admin';
        final isAdmin = authState.role == 'admin' || isSuperAdmin;
        final isTeacher = authState.role == 'teacher';
        final isStudent = authState.role == 'student';

        // Super Admin Guard: Only super_admin can access the Super Admin Console
        if (matched.startsWith('/admin/admin-management') && !isSuperAdmin) {
          return '/admin/dashboard';
        }

        if (isAdmin && (matched.startsWith('/student') || matched.startsWith('/teacher'))) {
          return '/admin/dashboard';
        }

        if (!isAdmin && matched.startsWith('/admin') && matched != '/admin/login') {
          return isTeacher ? '/teacher/dashboard' : '/student/home';
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
