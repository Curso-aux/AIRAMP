import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/admin/presentation/scores_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ScoresScreen Responsiveness Tests', () {
    testWidgets('ScoresScreen renders without overflow on compact screen (400x600)', (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ScoresScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Student Quiz Scores'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScoresScreen renders without overflow on non-fullscreen desktop window (800x550)', (tester) async {
      tester.view.physicalSize = const Size(800, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ScoresScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Student Quiz Scores'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ScoresScreen renders without overflow on standard window (1200x800)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ScoresScreen()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Student Quiz Scores'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
