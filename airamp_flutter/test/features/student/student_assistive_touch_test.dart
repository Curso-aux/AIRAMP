import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_assistive_touch.dart';
import 'package:airamp_flutter/src/core/components/aira/aira_floating_assistant.dart';

void main() {
  testWidgets('StudentAssistiveTouch renders floating assistant widget', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Student Dashboard')),
                StudentAssistiveTouch(
                  onCourses: () {},
                  onSchedule: () {},
                  onQuizzes: () {},
                  onProgress: () {},
                  onChat: () {},
                  onAnnouncements: () {},
                  onProfile: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(StudentAssistiveTouch), findsOneWidget);
    expect(find.byType(AiraFloatingAssistant), findsOneWidget);
  });

  testWidgets('StudentQuickActionsMenuDialog renders institutional academic shortcuts and triggers actions', (tester) async {
    bool coursesTapped = false;
    bool profileTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StudentQuickActionsMenuDialog(
            onCourses: () => coursesTapped = true,
            onSchedule: () {},
            onQuizzes: () {},
            onProgress: () {},
            onChat: () {},
            onAnnouncements: () {},
            onProfile: () => profileTapped = true,
          ),
        ),
      ),
    );

    // Dialog elements should be visible
    expect(find.text('Quick Actions Hub'), findsOneWidget);
    expect(find.text('Student shortcuts & academic tools'), findsOneWidget);
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('Subjects & units'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Class schedule'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('Assigned tasks'), findsOneWidget);
    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('Grades & stats'), findsOneWidget);
    expect(find.text('Ask Teacher'), findsOneWidget);
    expect(find.text('Chat & questions'), findsOneWidget);
    expect(find.text('Bulletins'), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsOneWidget);
    expect(find.text('Account details, appearance & security'), findsOneWidget);

    // Tap My Courses tile
    await tester.tap(find.text('My Courses'));
    await tester.pumpAndSettle();
    expect(coursesTapped, isTrue);

    // Tap Profile & Settings tile
    await tester.ensureVisible(find.text('Profile & Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile & Settings'));
    await tester.pumpAndSettle();
    expect(profileTapped, isTrue);
  });

  testWidgets('StudentAssistiveTouch toggles quick actions dialog open and closed on repeated clicks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StudentAssistiveTouch(
                  onCourses: () {},
                  onSchedule: () {},
                  onQuizzes: () {},
                  onProgress: () {},
                  onChat: () {},
                  onAnnouncements: () {},
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
    expect(find.byType(StudentQuickActionsMenuDialog), findsOneWidget);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isFalse);

    // Second click: closes Quick Actions Hub and reappears floating assistant
    final openAssistant = tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant));
    openAssistant.onOpenMenu();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StudentQuickActionsMenuDialog), findsNothing);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isTrue);

    // Third click: opens Quick Actions Hub again
    final reopenedAssistant = tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant));
    reopenedAssistant.onOpenMenu();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StudentQuickActionsMenuDialog), findsOneWidget);
    expect(tester.widget<AiraFloatingAssistant>(find.byType(AiraFloatingAssistant)).isVisible, isFalse);
  });
}
