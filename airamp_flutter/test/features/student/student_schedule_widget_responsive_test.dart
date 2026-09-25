import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_schedule_widget.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';

void main() {
  testWidgets('StudentScheduleWidget header renders cleanly on small screen without overflow', (tester) async {
    // Simulate narrow mobile screen (360 width, e.g. Samsung Galaxy S)
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sectionSchedulesProvider('Grade 10 - Emerald').overrideWith(
            (ref) async => <Map<String, dynamic>>[
              {
                'id': 'sched_test_1',
                'subject_name': 'Information Technology',
                'section_name': 'Grade 10 - Emerald',
                'day_of_week': getCurrentDayOfWeek(),
                'start_time': '08:00',
                'end_time': '10:00',
                'teacher_name': 'Teacher John',
                'room': 'Lab 1',
              },
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: StudentScheduleWidget(sectionName: 'Grade 10 - Emerald'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify elements rendered
    expect(find.text('Class Schedule'), findsOneWidget);
    expect(find.text('Grade 10 - Emerald'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WeeklyTimetableDialog header renders cleanly on small mobile screen (360x740) without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sectionSchedulesProvider('Grade 10 - Emerald').overrideWith(
            (ref) async => <Map<String, dynamic>>[],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WeeklyTimetableDialog(
              sectionName: 'Grade 10 - Emerald',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify elements rendered
    expect(find.text('Class Timetable Schedule'), findsOneWidget);
    expect(find.text('Grade 10 - Emerald'), findsOneWidget);
    expect(find.text('Grid'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
