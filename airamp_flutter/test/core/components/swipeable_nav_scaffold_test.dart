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

    testWidgets('6. Auto-hide bottom bar on downward scroll and reveal on upward scroll', (tester) async {
      final router = createTestRouter();
      await tester.pumpWidget(buildTestApp(router: router));
      await tester.pumpAndSettle();

      // Initially bar is visible (height > 0)
      final initialBarFinder = find.byType(BottomNavigationBar);
      expect(initialBarFinder, findsOneWidget);
      expect(tester.getBottomLeft(initialBarFinder).dy, greaterThan(500));

      // Scroll DOWN on the list view
      await tester.drag(find.byKey(const Key('tab0_list')), const Offset(0, -300));
      // Pump animation frames
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // In hidden state, the AnimatedContainer height shrinks to 0.0
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(animatedContainer.constraints?.maxHeight, equals(0.0));

      // Scroll UP on the list view
      await tester.drag(find.byKey(const Key('tab0_list')), const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Bottom bar is revealed again
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

      // Scroll down to hide bar
      await tester.drag(find.byKey(const Key('tab0_list')), const Offset(0, -300));
      await tester.pumpAndSettle();

      final hiddenContainer = tester.widget<AnimatedContainer>(
        find.ancestor(of: find.byType(BottomNavigationBar), matching: find.byType(AnimatedContainer)).first,
      );
      expect(hiddenContainer.constraints?.maxHeight, equals(0.0));

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
  });
}
