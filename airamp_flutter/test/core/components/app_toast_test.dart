import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/app_toast.dart';
import 'package:airamp_flutter/src/core/animations/app_transitions.dart';

void main() {
  group('AppToast Tests', () {
    testWidgets('showSuccess renders floating pill toast with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => AppToast.showSuccess(context, 'Quiz created successfully!'),
                  child: const Text('Show Success'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pumpAndSettle();

      expect(find.text('Quiz created successfully!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('showError renders error pill and triggers action callback on tap', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => AppToast.showError(
                    context,
                    'Failed to submit activity',
                    actionLabel: 'RETRY',
                    onAction: () => actionTriggered = true,
                  ),
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to submit activity'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();

      expect(actionTriggered, isTrue);
    });

    testWidgets('showWarning renders warning icon and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => AppToast.showWarning(context, 'You are in offline mode'),
                  child: const Text('Show Warning'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Warning'));
      await tester.pumpAndSettle();

      expect(find.text('You are in offline mode'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });
  });

  group('confirmDiscardChanges Tests', () {
    testWidgets('renders confirmation dialog and returns false when Keep Editing is tapped', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AppModalTransitions.confirmDiscardChanges(
                      context: context,
                      title: 'Discard Quiz Draft?',
                    );
                  },
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Discard Quiz Draft?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns true when Discard is tapped', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AppModalTransitions.confirmDiscardChanges(context: context);
                  },
                  child: const Text('Confirm'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });
  });
}
