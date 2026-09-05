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
import '../features/admin/presentation/sections_mgmt_screen.dart';
import '../features/admin/presentation/reg_links_screen.dart';
import '../features/admin/presentation/scores_screen.dart';
import '../features/admin/presentation/admin_profile_screen.dart';
import '../features/admin/presentation/admin_management_screen.dart';
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
      // Student Routes
      GoRoute(
        path: '/student/home',
        builder: (context, state) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/my-courses',
        builder: (context, state) => const MyCoursesScreen(),
      ),
      GoRoute(
        path: '/student/my-progress',
        builder: (context, state) => const MyProgressScreen(),
      ),
      GoRoute(
        path: '/student/quiz-history',
        builder: (context, state) => const QuizHistoryScreen(),
      ),
      GoRoute(
        path: '/student/student-profile',
        builder: (context, state) => const StudentProfileScreen(),
      ),
      // Admin Routes
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/subjects-mgmt',
        builder: (context, state) => const SubjectsMgmtScreen(),
      ),
      GoRoute(
        path: '/admin/sections-mgmt',
        builder: (context, state) => const SectionsMgmtScreen(),
      ),
      GoRoute(
        path: '/admin/reg-links',
        builder: (context, state) => const RegLinksScreen(),
      ),
      GoRoute(
        path: '/admin/scores',
        builder: (context, state) => const ScoresScreen(),
      ),
      GoRoute(
        path: '/admin/admin-profile',
        builder: (context, state) => const AdminProfileScreen(),
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
