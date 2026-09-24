import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';

class AdminScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      swipeDisabledIndices: const {4},
      selectedFontSize: 10,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_customize), label: 'Dashboard'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Subjects'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Sections'),
        BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: 'Scores'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.key), label: 'Access'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}
