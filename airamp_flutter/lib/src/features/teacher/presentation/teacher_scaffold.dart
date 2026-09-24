import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';
import 'web/teacher_web_scaffold.dart';

class TeacherScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const TeacherScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive Desktop Web layout with Collapsible Sidebar
    if (kIsWeb || screenWidth >= 900) {
      return TeacherWebScaffold(navigationShell: navigationShell);
    }

    // Mobile / Tablet layout with Swipeable and Auto-hiding Bottom Navigation Bar
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      // Chat is index 5: disable tab swipe on Chat so conversation dismissibles work cleanly
      swipeDisabledIndices: const {5},
      selectedFontSize: 9,
      unselectedFontSize: 9,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Subjects',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          activeIcon: Icon(Icons.calendar_month),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_turned_in_outlined),
          activeIcon: Icon(Icons.assignment_turned_in),
          label: 'Scores',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_outlined),
          activeIcon: Icon(Icons.people_alt),
          label: 'Students',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}
