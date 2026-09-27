import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/components/app_toast.dart';
import '../../../core/components/swipeable_nav_scaffold.dart';
import '../data/teacher_repository.dart';
import 'components/create_quiz_dialog.dart';
import 'components/post_announcement_dialog.dart';
import 'components/teacher_assistive_touch.dart';
import 'web/teacher_web_scaffold.dart';

class TeacherScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const TeacherScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;

    final assistiveTouch = TeacherAssistiveTouch(
      onCurriculum: () => context.go('/teacher/subjects'),
      onSchedule: () => context.go('/teacher/schedule'),
      onScores: () => context.go('/teacher/scores'),
      onStudents: () => context.go('/teacher/students'),
      onCreateQuiz: () {
        final subjects = ref.read(teacherSubjectsProvider);
        if (subjects.isEmpty) {
          AppToast.showWarning(
            context,
            'No subjects assigned. Please contact your admin to assign subjects first.',
          );
          return;
        }
        Navigator.of(context, rootNavigator: true).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (ctx) => CreateQuizDialog(
              initialSubjectId: subjects.first['id'] as int?,
              subjectName: subjects.first['name']?.toString() ?? 'Subject',
            ),
          ),
        );
      },
      onAnnounce: () => PostAnnouncementDialog.show(context),
      onProfile: () => context.push('/teacher/profile'),
    );

    // Responsive Desktop Web layout with Collapsible Sidebar
    if (kIsWeb || screenWidth >= 900) {
      return TeacherWebScaffold(
        navigationShell: navigationShell,
        floatingOverlay: assistiveTouch,
      );
    }

    // Mobile / Tablet layout with Swipeable and Auto-hiding Bottom Navigation Bar
    return SwipeableNavScaffold(
      navigationShell: navigationShell,
      floatingOverlay: assistiveTouch,
      // Chat is index 4: disable tab swipe on Chat so conversation dismissibles work cleanly
      swipeDisabledIndices: const {4},
      selectedFontSize: 11,
      unselectedFontSize: 11,
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
          icon: Icon(Icons.people_alt_outlined),
          activeIcon: Icon(Icons.people_alt),
          label: 'Students',
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
