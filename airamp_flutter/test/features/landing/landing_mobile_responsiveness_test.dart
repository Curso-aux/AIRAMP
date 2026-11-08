import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/landing/presentation/web_landing_screen.dart';
import 'package:airamp_flutter/src/features/landing/presentation/components/halftone_background.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    HalftoneBackground.enableAnimation = false;
  });

  group('Landing Page Mobile Responsiveness Tests', () {
    testWidgets('Renders hero section cleanly on 375px phone without any overflows', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Verify brand logo mark and title
      expect(find.text('Institutional Control & Unified Learning'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Institutional Infrastructure')),
        findsOneWidget,
      );

      // 2. Verify stacked action buttons
      expect(find.widgetWithText(ElevatedButton, 'Sign In to Portal'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'App Information'), findsOneWidget);

      // 3. Verify mobile touch targets >= 44px
      final signInBtn = tester.getRect(find.widgetWithText(ElevatedButton, 'Sign In to Portal'));
      expect(signInBtn.height, greaterThanOrEqualTo(44.0));

      final appInfoBtn = tester.getRect(find.widgetWithText(OutlinedButton, 'App Information'));
      expect(appInfoBtn.height, greaterThanOrEqualTo(44.0));

      // 4. Verify explore ecosystem prompt is present
      expect(find.text('Explore Ecosystem'), findsOneWidget);

      // 5. Verify no RenderFlex errors were thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mobile menu button opens navigation bottom sheet with quick links', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap hamburger menu icon button
      final menuBtn = find.byTooltip('Open Navigation Menu');
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify mobile bottom sheet opened with all key navigation items
      expect(find.text('AIRAMP Platform Navigation'), findsOneWidget);
      expect(find.text('Role Ecosystem'), findsWidgets);
      expect(find.text('School Assistant'), findsOneWidget);
      expect(find.text('Ecosystem Cloud'), findsOneWidget);
      expect(find.text('App Architecture & Info'), findsOneWidget);

      // Verify direct role portals
      expect(find.text('DIRECT ROLE PORTALS'), findsOneWidget);
      expect(find.text('Admin'), findsWidgets);
      expect(find.text('Teacher'), findsWidgets);
      expect(find.text('Student'), findsWidgets);

      // Tap to close via close button or backdrop
      final closeBtn = find.byIcon(Icons.close_rounded);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('AIRAMP Platform Navigation'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Explore Ecosystem scrolls down cleanly without errors', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final exploreBtn = find.text('Explore Ecosystem');
      expect(exploreBtn, findsOneWidget);
      await tester.tap(exploreBtn);
      await tester.pump(const Duration(milliseconds: 400));

      // Verify Role cards are in the tree
      expect(find.text('AIRAMP Role Ecosystem'), findsOneWidget);
      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mobile Segmented Role Console allows switching between Admin, Teacher, and Student cleanly', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll to Ecosystem section
      final exploreBtn = find.text('Explore Ecosystem');
      await tester.tap(exploreBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // 1. Initial active role is Admin
      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(find.text('Sign in as Admin →'), findsOneWidget);

      // Verify segmented tab buttons exist
      expect(find.text('Admin'), findsWidgets);
      expect(find.text('Teacher'), findsWidgets);
      expect(find.text('Student'), findsWidgets);

      // 2. Tap Teacher Tab
      await tester.tap(find.widgetWithText(InkWell, 'Teacher'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify card switched to Teacher Portal
      expect(find.text('Teacher Portal'), findsOneWidget);
      expect(find.text('Classroom & Scoring Hub'), findsOneWidget);
      expect(find.text('Sign in as Teacher →'), findsOneWidget);

      // 3. Tap Student Tab
      await tester.tap(find.widgetWithText(InkWell, 'Student'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify card switched to Student Portal
      expect(find.text('Student Portal'), findsOneWidget);
      expect(find.text('Personalized Learning'), findsOneWidget);
      expect(find.text('Sign in as Student →'), findsOneWidget);

      // 4. Tap Admin Tab back
      await tester.tap(find.widgetWithText(InkWell, 'Admin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(find.text('Sign in as Admin →'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Swipe gestures on Role Card navigates between roles cleanly', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll to Ecosystem
      await tester.tap(find.text('Explore Ecosystem'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Confirm starts at Admin
      expect(find.text('Admin Web Console'), findsOneWidget);

      // Fling Left on the Admin card to switch to Teacher
      await tester.fling(find.text('Admin Web Console'), const Offset(-200, 0), 1000.0, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Teacher Portal'), findsOneWidget);

      // Fling Left on Teacher card to switch to Student
      await tester.fling(find.text('Teacher Portal'), const Offset(-200, 0), 1000.0, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Student Portal'), findsOneWidget);

      // Fling Right on Student card to return to Teacher
      await tester.fling(find.text('Student Portal'), const Offset(200, 0), 1000.0, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Teacher Portal'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping App Information on mobile opens responsive bottom sheet without overflows', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Tap App Information button in hero
      final appInfoBtn = find.widgetWithText(OutlinedButton, 'App Information');
      expect(appInfoBtn, findsOneWidget);
      await tester.tap(appInfoBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Verify bottom sheet opens with rich architectural specs
      expect(find.text('AIRAMP Platform Architecture'), findsOneWidget);
      expect(find.text('MULTI-DEVICE ECOSYSTEM TARGETS'), findsOneWidget);

      // 2. Verify all 4 platform cards are present with full labels
      expect(find.text('Web Administration Console'), findsOneWidget);
      expect(find.text('Mobile Progressive Web App (PWA)'), findsOneWidget);
      expect(find.text('Windows Desktop Application'), findsOneWidget);
      expect(find.text('Embedded SQLite Local Engine'), findsOneWidget);

      // 3. Verify DepEd K-12 SHS Curriculum section
      expect(find.text('DEPED SENIOR HIGH SCHOOL CURRICULUM MODEL'), findsOneWidget);
      expect(find.text('1. Subjects'), findsOneWidget);
      expect(find.text('2. Topics'), findsOneWidget);
      expect(find.text('3. Learning Outcomes (LO)'), findsOneWidget);

      // 4. Verify Security & Isolation section
      expect(find.text('SECURITY & TENANT ISOLATION'), findsOneWidget);
      expect(find.text('Hierarchical Multi-Tenant RBAC'), findsOneWidget);

      // 5. Verify action buttons
      expect(find.widgetWithText(ElevatedButton, 'Sign In to Portal'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Close'), findsOneWidget);

      // 6. Close the bottom sheet
      await tester.tap(find.widgetWithText(OutlinedButton, 'Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('AIRAMP Platform Architecture'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Landing sections below Role Ecosystem render cleanly on mobile', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WebLandingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll to bottom of landing screen
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -1200));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Cross-Platform Ecosystem
      expect(find.text('Cross-Platform Ecosystem'), findsOneWidget);

      // Verify Access Guidelines
      expect(find.text('Institutional & Multi-Device Access Guidelines'), findsOneWidget);

      // Verify Footer with copyright
      expect(
        find.text('AIRAMP © 2026 Academic Integrated Review & Assessment Management Platform'),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
