import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/teacher_assistive_touch.dart';

void main() {
  testWidgets('TeacherAssistiveTouch renders floating bubble with touch icon', (tester) async {
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

    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
  });

  testWidgets('TeacherAssistiveTouch expands into glassmorphic quick actions dialog on tap', (tester) async {
    bool createQuizTapped = false;
    bool announceTapped = false;

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
                  onCreateQuiz: () => createQuizTapped = true,
                  onAnnounce: () => announceTapped = true,
                  onProfile: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Tap floating bubble
    await tester.tap(find.byIcon(Icons.touch_app_rounded));
    await tester.pumpAndSettle();

    // Dialog header elements should be visible
    expect(find.text('Quick Actions Hub'), findsOneWidget);
    expect(find.text('Teacher shortcuts & authoring tools'), findsOneWidget);

    // Squarish glass action tiles should be visible
    expect(find.text('Create Quiz'), findsOneWidget);
    expect(find.text('Announce'), findsOneWidget);
    expect(find.text('Curriculum'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Live Scores'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsOneWidget);

    // Tap Create Quiz tile
    await tester.tap(find.text('Create Quiz'));
    await tester.pumpAndSettle();
    expect(createQuizTapped, isTrue);
  });
}
