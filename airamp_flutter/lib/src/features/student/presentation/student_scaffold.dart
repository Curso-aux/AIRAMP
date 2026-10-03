import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';
import '../../auth/application/auth_provider.dart';
import 'components/student_announcements_sheet.dart';
import 'components/student_assistive_touch.dart';
import 'components/student_schedule_widget.dart';
import 'web/student_web_scaffold.dart';

class StudentScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const StudentScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final screenWidth = MediaQuery.of(context).size.width;

    final assistiveTouch = StudentAssistiveTouch(
      onCourses: () => context.go('/student/courses'),
      onSchedule: () {
        final sec = currentUser?.section;
        if (sec != null && sec.isNotEmpty) {
          showStudentTimetableModal(context, initialSection: sec);
        } else {
          showStudentTimetableModal(context);
        }
      },
      onQuizzes: () => context.go('/student/quiz-history'),
      onProgress: () => context.go('/student/progress'),
      onChat: () => context.go('/student/chat'),
      onAnnouncements: () => showStudentAnnouncementsFromRef(context, ref),
      onProfile: () => context.go('/student/profile'),
    );

    // Responsive Desktop Web layout with Collapsible Sidebar
    if (kIsWeb || screenWidth >= 900) {
      return StudentWebScaffold(
        navigationShell: navigationShell,
        floatingOverlay: assistiveTouch,
      );
    }

    // Mobile / Tablet layout with Swipeable and Auto-hiding Bottom Navigation Bar
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      // Chat is index 4: disable tab swipe on Chat so conversation dismissibles work cleanly
      swipeDisabledIndices: const {4},
      selectedFontSize: 11,
      unselectedFontSize: 11,
      floatingOverlay: assistiveTouch,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.menu_book_outlined),
          activeIcon: Icon(Icons.menu_book),
          label: 'Courses',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Progress',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.assignment_outlined),
          activeIcon: Icon(Icons.assignment),
          label: 'Quizzes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ),
      ],
    );
  }
}
