import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_assistive_touch.dart';

void main() {
  testWidgets('StudentAssistiveTouch renders floating bubble with touch icon', (tester) async {
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

    expect(find.byIcon(Icons.touch_app_rounded), findsOneWidget);
  });

  testWidgets('StudentAssistiveTouch expands into quick actions dialog on tap', (tester) async {
    bool coursesTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StudentAssistiveTouch(
                  onCourses: () => coursesTapped = true,
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

    // Tap floating bubble
    await tester.tap(find.byIcon(Icons.touch_app_rounded));
    await tester.pumpAndSettle();

    // Dialog elements should be visible
    expect(find.text('Quick Actions Hub'), findsOneWidget);
    expect(find.text('Student shortcuts & academic tools'), findsOneWidget);
    expect(find.text('My Courses'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Quizzes'), findsOneWidget);
    expect(find.text('My Progress'), findsOneWidget);
    expect(find.text('Ask Teacher'), findsOneWidget);
    expect(find.text('Bulletins'), findsOneWidget);
    expect(find.text('Profile & Settings'), findsOneWidget);

    // Tap My Courses tile
    await tester.tap(find.text('My Courses'));
    await tester.pumpAndSettle();
    expect(coursesTapped, isTrue);
  });
}
