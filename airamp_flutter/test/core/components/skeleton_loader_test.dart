import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/skeleton_loader.dart';

void main() {
  group('SkeletonLoader Tests', () {
    testWidgets('renders basic skeleton rectangle and text lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SkeletonLoader(width: 120, height: 20),
                const SkeletonLoader.circle(size: 40),
                SkeletonLoader.text(lines: 3),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoader), findsWidgets);
    });

    testWidgets('AppShimmer wraps children with shader mask', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              child: SkeletonCard(),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('SkeletonListView renders specified itemCount', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListView(
              itemCount: 4,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets('SkeletonListTile renders leading and trailing bones', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonListTile(
              hasLeading: true,
              hasTrailing: true,
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonListTile), findsOneWidget);
      expect(find.byType(SkeletonLoader), findsNWidgets(4));
    });
  });
}
