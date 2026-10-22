import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_provider.dart';
import '../../chat/application/chat_provider.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';
import 'web/student_web_scaffold.dart';

class StudentScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StudentScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final chatState = ref.watch(chatProvider);
    final unreadChatCount = chatState.conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    if (currentUser?.mustChangePassword == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/student/profile');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive Desktop Web layout with Collapsible Sidebar (Screens >= 900px)
    if (screenWidth >= 900) {
      return StudentWebScaffold(
        navigationShell: navigationShell,
      );
    }

    // Mobile / Tablet layout with Swipeable and Auto-hiding Bottom Navigation Bar
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      // Chat is index 4: disable tab swipe on Chat so conversation dismissibles work cleanly
      swipeDisabledIndices: const {4},
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Courses',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Progress',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'Quizzes',
        ),
        BottomNavigationBarItem(
          icon: unreadChatCount > 0
              ? Badge.count(
                  count: unreadChatCount,
                  child: const Icon(Icons.chat_bubble_outline),
                )
              : const Icon(Icons.chat_bubble_outline),
          activeIcon: unreadChatCount > 0
              ? Badge.count(
                  count: unreadChatCount,
                  child: const Icon(Icons.chat_bubble),
                )
              : const Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
      ],
    );
  }
}
