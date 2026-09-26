import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/components/swipeable_nav_scaffold.dart';

void main() {
  Widget buildTestApp({
    required GoRouter router,
  }) {
    return ProviderScope(
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }

  GoRouter createTestRouter({String initialLocation = '/tab0'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return SwipeableNavScaffold(
              navigationShell: navigationShell,
              swipeDisabledIndices: const {2}, // Tab 2 (Chat) has swipe disabled
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Courses'),
                BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
              ],
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tab0',
                  builder: (context, state) => ListView.builder(
                    key: const Key('tab0_list'),
                    itemCount: 60,
                    itemBuilder: (_, i) => SizedBox(
                      height: 50,
                      child: Text('Item $i'),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tab1',
                  builder: (context, state) => const Center(child: Text('Courses Screen Content')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tab2',
                  builder: (context, state) => const Center(child: Text('Chat Screen Content')),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/tab3',
                  builder: (context, state) => const Center(child: Text('Profile Screen Content')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  group('SwipeableNavScaffold Widget Tests', () {
    testWidgets('1. Renders navigation bar items and initial branch content cleanly', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('2. Tapping bottom navigation item switches to target branch', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // Tap on Courses tab
      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      expect(find.text('Courses Screen Content'), findsOneWidget);
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('3. Swiping left moves to next navigation tab', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);

      // Fling / drag left across screen (dx negative)
      await tester.fling(find.text('Item 0'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Should now be on Courses (tab 1)
      expect(find.text('Courses Screen Content'), findsOneWidget);
    });

    testWidgets('4. Swiping right moves to previous navigation tab', (tester) async {
      final router = createTestRouter(initialLocation: '/tab1');
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Courses Screen Content'), findsOneWidget);

      // Fling / drag right across screen (dx positive)
      await tester.fling(find.text('Courses Screen Content'), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // Should now be back on Dashboard (tab 0)
      expect(find.text('Item 0'), findsOneWidget);
    });

    testWidgets('5. Swiping on a swipe-disabled tab (e.g. Chat) is safely ignored', (tester) async {
      final router = createTestRouter(initialLocation: '/tab2');
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Chat Screen Content'), findsOneWidget);

      // Attempt swipe left
      await tester.fling(find.text('Chat Screen Content'), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Still on Chat Screen Content (not Profile)
      expect(find.text('Chat Screen Content'), findsOneWidget);
      expect(find.text('Profile Screen Content'), findsNothing);
    });

    testWidgets('6. Auto-hide bottom bar while actively scrolling and reveal when scrolling stops', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // Initially bar is visible (height > 0)
      final initialBarFinder = find.byType(BottomNavigationBar);
      expect(initialBarFinder, findsOneWidget);
      expect(tester.getBottomLeft(initialBarFinder).dy, greaterThan(500));

      // Start scrolling / dragging on the list view past touch slop
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('tab0_list'))));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      // While actively scrolling, bar hides (height set to 0.0)
      final hiddenDuringScroll = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(hiddenDuringScroll.constraints?.maxHeight, equals(0.0));

      // Release gesture: user stops scrolling
      await gesture.up();
      await tester.pumpAndSettle();

      // Bottom bar is revealed again once scrolling stops
      final revealedContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(revealedContainer.constraints?.maxHeight, greaterThan(50.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Switching tabs restores visibility of hidden bottom bar', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // While dragging, bar hides
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('tab0_list'))));
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      final hiddenContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(hiddenContainer.constraints?.maxHeight, equals(0.0));
      await gesture.up();

      // Swipe left to switch to Courses
      await tester.fling(find.byKey(const Key('tab0_list')), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Courses Screen Content'), findsOneWidget);

      // Bottom bar must be restored to visible
      final restoredContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(restoredContainer.constraints?.maxHeight, greaterThan(50.0));
    });

    testWidgets('8. Scrolling upwards (dragging down) immediately reveals navigation bar', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // Scroll down to hide bar
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('tab0_list'))));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();

      final hiddenContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(hiddenContainer.constraints?.maxHeight, equals(0.0));

      // Now scroll UP (drag down with positive dy)
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      final revealedOnScrollUp = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(revealedOnScrollUp.constraints?.maxHeight, greaterThan(50.0));
      await gesture.up();
    });

    testWidgets('9. Bottom navigation bar stays visible when at the bottom of the scroll view', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // Scroll all the way to the bottom item
      await tester.scrollUntilVisible(find.text('Item 59'), 500.0);
      await tester.pumpAndSettle();

      expect(find.text('Item 59'), findsOneWidget);

      final barContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(barContainer.constraints?.maxHeight, greaterThan(50.0));
    });
  });
}
