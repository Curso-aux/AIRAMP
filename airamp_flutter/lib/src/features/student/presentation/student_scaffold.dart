import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';

class StudentScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const StudentScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      // Chat is index 4: disable tab swipe on Chat so conversation dismissibles work cleanly
      swipeDisabledIndices: const {4},
      selectedFontSize: 10,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Courses'),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Progress'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'Quizzes'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
