import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/aira_action_toast.dart';

void main() {
  testWidgets('AiraActionToastCard renders light mode styling, icon, and actions correctly', (tester) async {
    bool dismissed = false;
    bool actionClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: AiraActionToastCard(
            title: 'Student record deleted',
            message: 'Student "Mark Bautista" (student_4) was permanently removed.',
            type: AiraToastType.success,
            duration: const Duration(seconds: 8),
            actionLabel: 'Okay',
            showStopButton: true,
            onAction: () {
              actionClicked = true;
            },
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    // Verify title and message are visible
    expect(find.text('Student record deleted'), findsOneWidget);
    expect(find.text('Student "Mark Bautista" (student_4) was permanently removed.'), findsOneWidget);
    expect(find.text('Okay'), findsOneWidget);

    // Verify initial countdown footer is present
    expect(find.textContaining('This message will close in'), findsOneWidget);
    expect(find.text('Click to stop.'), findsOneWidget);

    // Tap "Click to stop."
    await tester.tap(find.text('Click to stop.'));
    await tester.pump();

    // Verify countdown stops and updates text
    expect(find.textContaining('Auto-close paused.'), findsOneWidget);

    // Tap "Okay"
    await tester.tap(find.text('Okay'));
    await tester.pump();

    expect(actionClicked, isTrue);
    expect(dismissed, isTrue);
  });

  testWidgets('AiraActionToastCard renders dark mode styling and auto-dismisses on timeout', (tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: AiraActionToastCard(
            title: 'Changes saved',
            message: 'Record updated successfully.',
            type: AiraToastType.success,
            duration: const Duration(seconds: 4),
            actionLabel: 'Okay',
            showStopButton: true,
            onDismiss: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Changes saved'), findsOneWidget);
    expect(dismissed, isFalse);

    // Advance time past the 4 seconds duration
    await tester.pump(const Duration(seconds: 2));
    expect(dismissed, isFalse);

    await tester.pump(const Duration(seconds: 3));
    expect(dismissed, isTrue);
  });

  testWidgets('AiraActionToast.show displays floating toast in top-right overlay with entrance animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              return ElevatedButton(
                onPressed: () {
                  AiraActionToast.showSuccess(
                    ctx,
                    title: 'Student record deleted',
                    message: 'Deleted successfully.',
                  );
                },
                child: const Text('Delete Student'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete Student'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Student record deleted'), findsOneWidget);
    expect(find.text('Okay'), findsOneWidget);

    // Verify top-right positioning: top offset should be near top (< 100), right alignment
    final toastFinder = find.text('Student record deleted');
    final topLeft = tester.getTopLeft(toastFinder);
    expect(topLeft.dy, lessThan(120)); // High up on screen
    expect(topLeft.dx, greaterThan(200)); // To the right side

    // Dismiss by tapping Okay
    await tester.tap(find.text('Okay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Toast should be dismissed
    expect(find.text('Student record deleted'), findsNothing);
  });
}

