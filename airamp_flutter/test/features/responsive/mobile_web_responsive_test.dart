import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/auth/presentation/web/admin_web_login_screen.dart';
import 'package:airamp_flutter/src/features/landing/presentation/web_landing_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_analytics_view.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';

class _TestAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalUsers': 12,
      'totalStudents': 8,
      'totalTeachers': 3,
      'totalAdmins': 1,
      'totalEnrollments': 15,
      'totalSubjects': 4,
      'totalTopics': 8,
      'totalLos': 20,
      'totalAttempts': 10,
      'passedAttempts': 8,
      'passRate': 80,
      'avgScore': 85,
      'subjectEnrollments': <Map<String, dynamic>>[],
      'sectionDistribution': <Map<String, dynamic>>[],
      'recentAnnouncements': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
      'hasData': true,
    };
  }

  @override
  Future<void> loadAnalytics({AnalyticsFilter? filter}) async {}
}

class _TestSubjectsNotifier extends SubjectsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {'id': 1, 'name': 'Computer Systems Servicing', 'subject_code': 'CSS-NC-II'},
  ];
}

class _TestSectionsNotifier extends SectionsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {'id': 1, 'name': 'Emerald', 'grade': 'Grade 10'},
  ];
}

void main() {
  group('Mobile Web Responsiveness Tests (iOS & Android)', () {
    testWidgets('WebLandingScreen renders cleanly on Android viewport (360x740) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WebLandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AIRA'), findsOneWidget);
      expect(find.text('PORTAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WebLandingScreen renders cleanly on iPhone viewport (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: WebLandingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AIRA'), findsOneWidget);
      expect(find.text('PORTAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebLoginScreen renders cleanly on Android viewport (360x740) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminWebLoginScreen(initialRole: 'admin'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(find.text('Sign In to Admin Console'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebLoginScreen renders cleanly on iPhone viewport (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminWebLoginScreen(initialRole: 'admin'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Admin Web Console'), findsOneWidget);
      expect(find.text('Sign In to Admin Console'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebAnalyticsView renders cleanly on mobile screen (360x740) without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAnalyticsProvider.overrideWith(() => _TestAnalyticsNotifier()),
            subjectsProvider.overrideWith(() => _TestSubjectsNotifier()),
            sectionsProvider.overrideWith(() => _TestSectionsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdminWebAnalyticsView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Analytics & Operations'), findsOneWidget);
      expect(find.text('Refresh Data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
