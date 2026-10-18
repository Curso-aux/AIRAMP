import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../routing/app_router.dart';
import '../../../features/auth/application/auth_provider.dart';
import '../../../features/student/presentation/components/student_assistive_touch.dart';
import '../../../features/student/presentation/components/student_schedule_widget.dart';
import '../../../features/student/presentation/components/student_announcements_sheet.dart';
import '../../../features/teacher/presentation/components/teacher_assistive_touch.dart';
import '../../../features/teacher/presentation/components/create_quiz_dialog.dart';
import '../../../features/teacher/presentation/components/post_announcement_dialog.dart';
import '../../../features/teacher/data/teacher_repository.dart';
import '../app_toast.dart';

/// Topmost application-level overlay that keeps AIRA floating seamlessly
/// above ALL pages, modal sheets, dialogs, and popups.
///
/// Features:
/// - Floats above both base pages AND any modals pushed to the Navigator
/// - Enables holding AIRA to scan modals, dialogs, or sheets directly
/// - Dispatches student or teacher quick action hubs depending on authenticated role
/// - Completely transparent and click-through for all non-AIRA screen areas
class GlobalAiraFloatingOverlay extends ConsumerWidget {
  const GlobalAiraFloatingOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    if (currentUser == null) return const SizedBox.shrink();

    // Admins do not use AIRA
    if (currentUser.role == 'admin' || currentUser.role == 'super_admin') {
      return const SizedBox.shrink();
    }

    final router = ref.watch(routerProvider);
    final location = router.routerDelegate.currentConfiguration.uri.path;

    // Do not show on auth or landing screens
    if (location.isEmpty ||
        location == '/' ||
        location.startsWith('/login') ||
        location.startsWith('/signup') ||
        location.startsWith('/forgot-password') ||
        location.startsWith('/admin')) {
      return const SizedBox.shrink();
    }

    Widget assistant = const SizedBox.shrink();

    // Student Assistant
    if (currentUser.role == 'student' || location.startsWith('/student')) {
      assistant = StudentAssistiveTouch(
        onCourses: () => router.go('/student/courses'),
        onSchedule: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            final sec = currentUser.section;
            if (sec != null && sec.isNotEmpty) {
              showStudentTimetableModal(navContext, initialSection: sec);
            } else {
              showStudentTimetableModal(navContext);
            }
          }
        },
        onQuizzes: () => router.go('/student/quiz-history'),
        onProgress: () => router.go('/student/progress'),
        onChat: () => router.go('/student/chat'),
        onAnnouncements: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            showStudentAnnouncementsFromRef(navContext, ref);
          }
        },
        onProfile: () => router.go('/student/profile'),
      );
    } else if (currentUser.role == 'teacher' || location.startsWith('/teacher')) {
      assistant = TeacherAssistiveTouch(
        onCurriculum: () => router.go('/teacher/subjects'),
        onSchedule: () => router.go('/teacher/schedule'),
        onScores: () => router.go('/teacher/scores'),
        onStudents: () => router.go('/teacher/students'),
        onCreateQuiz: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext == null) return;

          final subjects = ref.read(teacherSubjectsProvider);
          if (subjects.isEmpty) {
            AppToast.showWarning(
              navContext,
              'No subjects assigned. Please contact your admin to assign subjects first.',
            );
            return;
          }
          Navigator.of(navContext, rootNavigator: true).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (ctx) => CreateQuizDialog(
                initialSubjectId: subjects.first['id'] as int?,
                subjectName: subjects.first['name']?.toString() ?? 'Subject',
              ),
            ),
          );
        },
        onAnnounce: () {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            PostAnnouncementDialog.show(navContext);
          }
        },
        onProfile: () => router.push('/teacher/profile'),
      );
    }

    if (assistant is SizedBox) return assistant;

    return Material(
      type: MaterialType.transparency,
      child: assistant,
    );
  }
}
