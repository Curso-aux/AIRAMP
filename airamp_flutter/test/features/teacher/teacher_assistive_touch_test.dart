import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/teacher_assistive_touch.dart';
import 'package:airamp_flutter/src/core/components/aira/aira_floating_assistant.dart';

void main() {
  testWidgets('TeacherAssistiveTouch renders floating assistant widget', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Teacher Dashboard')),
                TeacherAssistiveTouch(
                  onCurriculum: () {},
                  onSchedule: () {},
                  onScores: () {},
                  onStudents: () {},
                  onCreateQuiz: () {},
                  onAnnounce: () {},
                  onProfile: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TeacherAssistiveTouch), findsOneWidget);
    expect(find.byType(AiraFloatingAssistant), findsOneWidget);
  });

  testWidgets('TeacherQuickActionsMenuDialog renders institutional academic shortcuts and triggers actions', (tester) async {
    bool createQuizTapped = false;
    bool announceTapped = false;
    bool curriculumTapped = false;
    bool scheduleTapped = false;
    bool scoresTapped = false;
    bool studentsTapped = false;
    bool profileTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TeacherQuickActionsMenuDialog(
            onCreateQuiz: () => createQuizTapped = true,
            onAnnounce: () => announceTapped = true,
            onCurriculum: () => curriculumTapped = true,
            onSchedule: () => scheduleTapped = true,
            onScores: () => scoresTapped = true,
            onStudents: () => studentsTapped = true,
            onProfile: () => profileTapped = true,
          ),
        ),
      ),
    );

    // Dialog elements should be visible
    expect(find.text('Quick Actions Hub'), findsOneWidget);
    expect(find.text('Teacher shortcuts & authoring tools'), findsOneWidget);
    expect(find.text('Create Quiz'), findsOneWidget);
    expect(find.text('Draft & launch'), findsOneWidget);
    expect(find.text('Announce'), findsOneWidget);
    expect(find.text('Post updates'), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('Subjects & units'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Class timetable'), findsOneWidget);
    expect(find.text('Live Scores'), findsOneWidget);
    expect(find.text('Submissions health'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Section roster'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Account details, appearance & security'), findsOneWidget);

    // Tap Create Quiz tile
    await tester.tap(find.text('Create Quiz'));
    await tester.pumpAndSettle();
    expect(createQuizTapped, isTrue);

    // Tap Profile & Settings tile
    await tester.ensureVisible(find.text('Profile & Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile & Settings'));
    await tester.pumpAndSettle();
    expect(profileTapped, isTrue);
  });

  testWidgets('TeacherAssistiveTouch toggles quick actions dialog open and closed on repeated clicks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TeacherAssistiveTouch(
                  onCurriculum: () {},
                  onSchedule: () {},
                  onScores: () {},
                  onStudents: () {},
                  onCreateQuiz: () {},
                  onAnnounce: () {},
                  onProfile: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final initialAssistant = tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant));
    expect(initialAssistant.isVisible, isTrue);

    // First click: opens Quick Actions Hub and hides floating assistant
    initialAssistant.onOpenMenu();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TeacherQuickActionsMenuDialog), findsOneWidget);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isFalse);

    // Second click: closes Quick Actions Hub and reappears floating assistant
    final openAssistant = tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant));
    openAssistant.onOpenMenu();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TeacherQuickActionsMenuDialog), findsNothing);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isTrue);

    // Third click: opens Quick Actions Hub again
    final reopenedAssistant = tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant));
    reopenedAssistant.onOpenMenu();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TeacherQuickActionsMenuDialog), findsOneWidget);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isFalse);
  });
}
