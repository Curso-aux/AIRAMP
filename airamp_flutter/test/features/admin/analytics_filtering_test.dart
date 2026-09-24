import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_analytics_view.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/components/analytics_filter_bar.dart';

class _MockSubjectsNotifier extends SubjectsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {'id': 1, 'name': 'Computer Systems Servicing', 'subject_code': 'CSS-NC-II'},
    {'id': 2, 'name': 'Empowerment Technologies', 'subject_code': 'EMTECH'},
  ];
}

class _MockSectionsNotifier extends SectionsNotifier {
  @override
  List<Map<String, dynamic>> build() => [
    {'id': 1, 'name': 'Emerald', 'grade': 'Grade 10'},
    {'id': 2, 'name': 'STEM A', 'grade': 'Grade 11'},
  ];
}

class _MockAnalyticsNotifier extends AdminAnalyticsNotifier {
  @override
  Map<String, dynamic> build() {
    return {
      'totalUsers': 25,
      'totalStudents': 20,
      'totalTeachers': 4,
      'totalAdmins': 1,
      'totalEnrollments': 35,
      'totalSubjects': 5,
      'totalTopics': 12,
      'totalLos': 30,
      'totalAttempts': 18,
      'passedAttempts': 15,
      'passRate': 83,
      'avgScore': 86,
      'subjectEnrollments': <Map<String, dynamic>>[
        {'id': 1, 'code': 'CSS', 'name': 'Computer Systems Servicing', 'enrollments': 20},
      ],
      'sectionDistribution': <Map<String, dynamic>>[
        {'section': 'Emerald', 'count': 12},
        {'section': 'STEM A', 'count': 8},
      ],
      'recentAnnouncements': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
      'hasData': true,
    };
  }

  @override
  Future<void> loadAnalytics({AnalyticsFilter? filter}) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AnalyticsFilter Model Tests', () {
    test('default filter has no active filters', () {
      const filter = AnalyticsFilter();
      expect(filter.hasActiveFilters, isFalse);
      expect(filter.activeFilterCount, equals(0));
      expect(filter.timeframe, equals('all'));
      expect(filter.category, equals('all'));
      expect(filter.subjectId, isNull);
      expect(filter.section, isNull);
    });

    test('setting filters correctly updates hasActiveFilters and count', () {
      var filter = const AnalyticsFilter();
      filter = filter.copyWith(subjectId: 1, subjectName: 'CSS');
      expect(filter.hasActiveFilters, isTrue);
      expect(filter.activeFilterCount, equals(1));

      filter = filter.copyWith(section: 'Emerald');
      expect(filter.activeFilterCount, equals(2));

      filter = filter.copyWith(timeframe: '7days');
      expect(filter.activeFilterCount, equals(3));

      filter = filter.copyWith(category: 'irregular');
      expect(filter.activeFilterCount, equals(4));

      // Clear subject
      filter = filter.copyWith(clearSubject: true);
      expect(filter.activeFilterCount, equals(3));
      expect(filter.subjectId, isNull);
    });
  });

  group('DatabaseHelper Multi-Dimensional Analytics Filtering (AND Logic)', () {
    test('getAdminAnalyticsSummary with no filter returns baseline metrics', () async {
      final db = DatabaseHelper();
      final summary = await db.getAdminAnalyticsSummary();

      expect(summary.containsKey('totalUsers'), isTrue);
      expect(summary.containsKey('totalStudents'), isTrue);
      expect(summary.containsKey('totalEnrollments'), isTrue);
      expect(summary.containsKey('passRate'), isTrue);
      expect(summary.containsKey('hasData'), isTrue);
    });

    test('getAdminAnalyticsSummary filters by section and timeframe with AND logic', () async {
      final db = DatabaseHelper();
      final summary = await db.getAdminAnalyticsSummary(
        section: 'Emerald',
        timeframe: '7days',
        studentCategory: 'regular',
      );

      expect(summary.containsKey('totalStudents'), isTrue);
      expect(summary.containsKey('totalAttempts'), isTrue);
      expect(summary.containsKey('subjectEnrollments'), isTrue);
      expect(summary.containsKey('sectionDistribution'), isTrue);
    });

    test('getAdminAnalyticsSummary returns hasData false when filters yield 0 matches', () async {
      final db = DatabaseHelper();
      final summary = await db.getAdminAnalyticsSummary(
        section: 'NonExistentSectionXYZ_999',
        subjectId: 99999,
      );

      expect(summary['totalStudents'], equals(0));
      expect(summary['totalEnrollments'], equals(0));
      expect(summary['totalAttempts'], equals(0));
      expect(summary['hasData'], isFalse);
    });
  });

  group('AnalyticsFilterBar & Web Analytics View UI / Small Screen Tests', () {
    testWidgets('AnalyticsFilterBar renders compact bar and triggers panel', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith(() => _MockSubjectsNotifier()),
            sectionsProvider.overrideWith(() => _MockSectionsNotifier()),
            adminAnalyticsProvider.overrideWith(() => _MockAnalyticsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16.0),
                child: AnalyticsFilterBar(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filter Analytics'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);

      // Tap Filter Analytics button to expand panel on desktop
      await tester.tap(find.text('Filter Analytics'));
      await tester.pumpAndSettle();

      expect(find.text('Filter Dimensions (Combinable via AND Logic)'), findsOneWidget);
      expect(find.text('Subject'), findsOneWidget);
      expect(find.text('Class Section'), findsOneWidget);
      expect(find.text('Date Range'), findsOneWidget);
      expect(find.text('Student Category'), findsOneWidget);
    });

    testWidgets('AnalyticsFilterBar handles small screen width (360px) without overflow', (tester) async {
      // Simulate small mobile viewport (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith(() => _MockSubjectsNotifier()),
            sectionsProvider.overrideWith(() => _MockSectionsNotifier()),
            adminAnalyticsProvider.overrideWith(() => _MockAnalyticsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(12.0),
                child: AnalyticsFilterBar(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On narrow mobile, renders compact 'Filters' button without overflow
      expect(find.text('Filters'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap opens modal bottom sheet
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Analytics Filters'), findsOneWidget);
      expect(find.text('Apply & Close'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminWebAnalyticsView renders with filter bar and reacts to empty state', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectsProvider.overrideWith(() => _MockSubjectsNotifier()),
            sectionsProvider.overrideWith(() => _MockSectionsNotifier()),
            adminAnalyticsProvider.overrideWith(() => _MockAnalyticsNotifier()),
          ],
          child: const MaterialApp(
            home: AdminWebAnalyticsView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('School Analytics & Operations'), findsOneWidget);
      expect(find.byType(AnalyticsFilterBar), findsOneWidget);
      expect(find.text('Total Users Registered'), findsOneWidget);
      expect(find.text('Assessment Pass Rate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
