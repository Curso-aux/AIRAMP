import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/empty_state.dart';

void main() {
  group('EmptyState backwards compatibility', () {
    testWidgets('renders message and triggers onAction callback', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              message: 'No quizzes assigned yet',
              actionLabel: 'Refresh',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('No quizzes assigned yet'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(actionTriggered, isTrue);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders headline, description and primary action button', (tester) async {
      bool clicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'No Quiz Scores Found',
              message: 'No scores have been recorded for this section yet.',
              icon: Icons.assignment_outlined,
              actionLabel: 'View All Sections',
              onAction: () => clicked = true,
            ),
          ),
        ),
      );

      expect(find.text('No Quiz Scores Found'), findsOneWidget);
      expect(find.text('No scores have been recorded for this section yet.'), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      expect(find.text('View All Sections'), findsOneWidget);

      await tester.tap(find.text('View All Sections'));
      await tester.pumpAndSettle();

      expect(clicked, isTrue);
    });

    testWidgets('AppEmptyState.search generates intelligent copy and clear button', (tester) async {
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState.search(
              query: 'Calculus',
              onClearSearch: () => cleared = true,
            ),
          ),
        ),
      );

      expect(find.text('No Results Found'), findsOneWidget);
      expect(find.textContaining('No items matched "Calculus"'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);

      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
    });
  });

  group('AppErrorState', () {
    testWidgets('intelligently interprets SocketException as offline with 1-tap retry', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              error: const SocketException('Failed host lookup: api.school.edu'),
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.textContaining('Please check your Wi-Fi or cellular network'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });

    testWidgets('intelligently interprets 401 unauthorized errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              error: 'Http 401 Unauthorized access token has expired',
            ),
          ),
        ),
      );

      expect(find.text('Session Expired'), findsOneWidget);
      expect(find.textContaining('Please log in again to continue'), findsOneWidget);
      expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
    });

    testWidgets('toggles technical details on user request', (tester) async {
      const errorMsg = 'ClientException: Database deadlock detected on table quizzes_v2';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              error: errorMsg,
            ),
          ),
        ),
      );

      expect(find.text('View technical info'), findsOneWidget);
      expect(find.text(errorMsg), findsNothing);

      await tester.tap(find.text('View technical info'));
      await tester.pumpAndSettle();

      expect(find.text('Hide technical info'), findsOneWidget);
      expect(find.text(errorMsg), findsOneWidget);
    });
  });
}
