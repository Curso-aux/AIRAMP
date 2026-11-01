import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_analytics_sheet.dart';
import 'package:airamp_flutter/src/features/student/data/student_repository.dart';

class _MockCoursesNotifier extends StudentCoursesNotifier {
  final List<Map<String, dynamic>> _data;
  _MockCoursesNotifier(this._data);

  @override
  List<Map<String, dynamic>> build() => _data;
}

class _MockProgressNotifier extends StudentProgressNotifier {
  final Map<String, dynamic> _data;
  _MockProgressNotifier(this._data);

  @override
  Map<String, dynamic> build() => _data;
}

class _MockQuizzesNotifier extends StudentQuizAssignmentsNotifier {
  final List<Map<String, dynamic>> _data;
  _MockQuizzesNotifier(this._data);

  @override
  List<Map<String, dynamic>> build() => _data;
}

void main() {
  final mockCourses = [
    {
      'id': 1,
      'code': 'CS101',
      'subject_code': 'CS101',
      'name': 'Introduction to Flutter & Dart',
      'completed_los': 1,
      'total_los': 3,
    },
    {
      'id': 2,
      'code': 'CS202',
      'subject_code': 'CS202',
      'name': 'Mobile UI & State Management',
      'completed_los': 0,
      'total_los': 1,
    },
  ];

  final mockProgress = {
    'activeCourses': 2,
    'completed': 1,
    'total': 4,
    'pending': 3,
    'average': 78.5,
    'best': 85.0,
    'totalAttempts': 2,
    'passedAttempts': 2,
  };

  final mockQuizzes = [
    {
      'quiz_id': 101,
      'title': 'CS101: Midterm Quiz Assessment',
      'subject_code': 'CS101',
      'status': 'pending',
      'due_date': '2026-10-27T23:59:59.000', // overdue
    },
  ];

  testWidgets('1. StudentAnalyticsSheet renders Descriptive analytics by default', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCoursesProvider.overrideWith(() => _MockCoursesNotifier(mockCourses)),
          studentProgressProvider.overrideWith(() => _MockProgressNotifier(mockProgress)),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizzesNotifier(mockQuizzes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudentAnalyticsSheet(isDesktop: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header title and 3-tier tab switcher
    expect(find.text('My Progress & Analytics'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Next Steps'), findsOneWidget);

    // Verify Descriptive elements
    expect(find.text('Active Courses'), findsOneWidget);
    expect(find.text('Lessons Done'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Course Progress'), findsOneWidget);
    expect(find.text('CS101'), findsOneWidget);
    expect(find.text('CS202'), findsOneWidget);
  });

  testWidgets('2. Tapping Forecast tab transitions to completion pace and risk trajectory', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCoursesProvider.overrideWith(() => _MockCoursesNotifier(mockCourses)),
          studentProgressProvider.overrideWith(() => _MockProgressNotifier(mockProgress)),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizzesNotifier(mockQuizzes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudentAnalyticsSheet(isDesktop: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Forecast Tab
    await tester.tap(find.text('Forecast'));
    await tester.pumpAndSettle();

    // Verify Predictive elements
    expect(find.text('Learning Pace & Timeline'), findsOneWidget);
    expect(find.text('Assessment Readiness'), findsOneWidget);
    expect(find.text('Subject Pace & Outlook'), findsOneWidget);
    expect(find.text('Elevated Risk: 1 Overdue Assessment'), findsOneWidget);
  });

  testWidgets('3. Tapping Next Steps tab renders prioritized actionable interventions with CTAs', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCoursesProvider.overrideWith(() => _MockCoursesNotifier(mockCourses)),
          studentProgressProvider.overrideWith(() => _MockProgressNotifier(mockProgress)),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizzesNotifier(mockQuizzes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: StudentAnalyticsSheet(isDesktop: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Next Steps Tab
    await tester.tap(find.text('Next Steps'));
    await tester.pumpAndSettle();

    // Verify Prescriptive elements
    expect(find.text('Recommended Next Actions'), findsOneWidget);
    expect(find.text('3 Priority Tasks'), findsOneWidget);
    expect(find.text('Take Quiz Now'), findsOneWidget);
    expect(find.text('Open Course'), findsOneWidget);
    expect(find.text('View Schedule'), findsOneWidget);
    expect(find.text('Next Goals & Study Tips'), findsOneWidget);
  });

  testWidgets('4. Mobile viewport (375x812) renders all 3 tabs without overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentCoursesProvider.overrideWith(() => _MockCoursesNotifier(mockCourses)),
          studentProgressProvider.overrideWith(() => _MockProgressNotifier(mockProgress)),
          studentQuizAssignmentsProvider.overrideWith(() => _MockQuizzesNotifier(mockQuizzes)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: StudentAnalyticsSheet(isDesktop: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Overview tab on mobile
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('Next Steps'), findsOneWidget);

    // Switch to Forecast
    await tester.tap(find.text('Forecast'));
    await tester.pumpAndSettle();
    expect(find.text('Learning Pace & Timeline'), findsOneWidget);

    // Switch to Next Steps
    await tester.tap(find.text('Next Steps'));
    await tester.pumpAndSettle();
    expect(find.text('Recommended Next Actions'), findsOneWidget);
  });
}
