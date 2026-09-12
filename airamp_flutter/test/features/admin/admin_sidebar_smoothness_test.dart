import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/core/theme/theme_provider.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_scaffold.dart';

void main() {
  testWidgets('AdminWebScaffold sidebar toggles between expanded and collapsed smoothly with ZERO overflow errors', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testRouter = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AdminWebScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/dashboard',
                  builder: (context, state) => const Scaffold(body: Center(child: Text('Dashboard Content'))),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          routerConfig: testRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial expanded state
    expect(find.text('AIRAMP'), findsOneWidget);
    expect(find.text('Web Admin Portal'), findsOneWidget);
    expect(find.text('Dashboard Content'), findsOneWidget);

    // Find the sidebar toggle button in the top bar
    final toggleFinder = find.byTooltip('Collapse sidebar');
    expect(toggleFinder, findsOneWidget);

    // Toggle to compress the sidebar
    await tester.tap(toggleFinder);
    // Pump several intermediate animation frames to verify NO RenderFlex overflows occur during the transition
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // In collapsed mode, the tooltip should now be 'Expand sidebar'
    final expandFinder = find.byTooltip('Expand sidebar');
    expect(expandFinder, findsOneWidget);

    // Toggle back to expand the sidebar
    await tester.tap(expandFinder);
    // Pump intermediate animation frames again
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Check that expanded elements are restored cleanly
    expect(find.text('AIRAMP'), findsOneWidget);
    expect(find.text('Web Admin Portal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Theme toggle switches between light and dark mode without throwing or dropping tree state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initially dark
    expect(container.read(themeProvider).isDark, isTrue);

    // Toggle to light
    container.read(themeProvider.notifier).toggleTheme();
    expect(container.read(themeProvider).isDark, isFalse);
    expect(AppTheme.isDark, isFalse);

    // Toggle back to dark
    container.read(themeProvider.notifier).toggleTheme();
    expect(container.read(themeProvider).isDark, isTrue);
    expect(AppTheme.isDark, isTrue);
  });

  testWidgets('Top bar mode switch button and role badge are aligned to the far right side of the screen', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testRouter = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AdminWebScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/admin/dashboard',
                  builder: (context, state) => const Scaffold(body: Center(child: Text('Content'))),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          routerConfig: testRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify mode switch icon is found
    final themeToggleFinder = find.byTooltip('Switch to Light Mode');
    expect(themeToggleFinder, findsOneWidget);

    final themeToggleOffset = tester.getTopLeft(themeToggleFinder);
    // On a 1280px wide window with a 260px sidebar, the theme toggle and role badge occupy the far right (x ~ 1007 to 1256)
    expect(themeToggleOffset.dx, greaterThan(980.0));

    // Role badge should be to the right of the theme toggle
    final roleBadgeFinder = find.text('ADMINISTRATOR');
    expect(roleBadgeFinder, findsOneWidget);
    final roleBadgeOffset = tester.getTopLeft(roleBadgeFinder);
    expect(roleBadgeOffset.dx, greaterThan(themeToggleOffset.dx));

    // Role badge should be positioned right next to the 24px right padding
    final roleBadgeRect = tester.getRect(find.ancestor(of: roleBadgeFinder, matching: find.byType(Container)).first);
    expect(roleBadgeRect.right, closeTo(1280.0 - 24.0, 5.0));
  });
}
