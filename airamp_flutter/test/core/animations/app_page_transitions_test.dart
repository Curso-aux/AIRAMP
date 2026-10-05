import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/core/animations/app_page_transitions.dart';

void main() {
  group('AppPageTransitions Tests', () {
    test('webFadeThrough returns CustomTransitionPage with 220ms duration', () {
      final page = AppPageTransitions.webFadeThrough(
        key: const ValueKey('test_key'),
        child: const SizedBox(key: ValueKey('test_child')),
      );

      expect(page, isA<CustomTransitionPage>());
      final customPage = page as CustomTransitionPage;
      expect(customPage.transitionDuration, const Duration(milliseconds: 220));
      expect(customPage.reverseTransitionDuration, const Duration(milliseconds: 180));
    });

    test('slidePush returns CustomTransitionPage with 280ms duration', () {
      final page = AppPageTransitions.slidePush(
        key: const ValueKey('slide_key'),
        child: const SizedBox(),
      );

      expect(page, isA<CustomTransitionPage>());
      final customPage = page as CustomTransitionPage;
      expect(customPage.transitionDuration, const Duration(milliseconds: 280));
      expect(customPage.reverseTransitionDuration, const Duration(milliseconds: 240));
    });

    test('activityModal returns CustomTransitionPage with 260ms duration', () {
      final page = AppPageTransitions.activityModal(
        key: const ValueKey('modal_key'),
        child: const SizedBox(),
      );

      expect(page, isA<CustomTransitionPage>());
      final customPage = page as CustomTransitionPage;
      expect(customPage.transitionDuration, const Duration(milliseconds: 260));
    });

    test('fadeThrough returns CustomTransitionPage with 200ms duration', () {
      final page = AppPageTransitions.fadeThrough(
        key: const ValueKey('fade_key'),
        child: const SizedBox(),
      );

      expect(page, isA<CustomTransitionPage>());
      final customPage = page as CustomTransitionPage;
      expect(customPage.transitionDuration, const Duration(milliseconds: 200));
    });

    testWidgets('AppBranchTransition animates seamlessly on index change', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBranchTransition(
              currentIndex: 0,
              child: Text('Tab 0 View'),
            ),
          ),
        ),
      );

      expect(find.text('Tab 0 View'), findsOneWidget);

      // Re-pump with new tab index
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBranchTransition(
              currentIndex: 1,
              child: Text('Tab 1 View'),
            ),
          ),
        ),
      );

      // Advance animation halfway
      await tester.pump(const Duration(milliseconds: 90));
      expect(find.text('Tab 1 View'), findsOneWidget);

      // Complete transition
      await tester.pumpAndSettle();
      expect(find.text('Tab 1 View'), findsOneWidget);
    });
  });
}
