import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Center(child: Text('Home / Index')));
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) {
          return const SignupScreen();
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Center(child: Text('Admin Dashboard')));
        },
      ),
      GoRoute(
        path: '/student',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Center(child: Text('Student Dashboard')));
        },
      ),
    ],
  );
}
