import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/components/calendar/actual_calendar_view.dart';

void main() {
  final sampleSchedules = [
    {
      'id': 'sched_1',
      'subject_name': 'Software Engineering',
      'section_name': 'BSIT 3-A',
      'teacher_name': 'Prof. Alan Turing',
      'day_of_week': 'Monday',
      'start_time': '08:00',
      'end_time': '10:00',
      'room': 'Lab 101',
      'color_code': '#10B981',
    },
    {
      'id': 'sched_2',
      'subject_name': 'Database Systems',
      'section_name': 'BSIT 3-A',
      'teacher_name': 'Dr. Grace Hopper',
      'day_of_week': 'Friday',
      'start_time': '13:00',
      'end_time': '15:00',
      'room': 'Room 304',
      'color_code': '#3B82F6',
    },
  ];

  testWidgets('ActualCalendarView renders month header, weekdays, and today button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActualCalendarView(
            schedules: sampleSchedules,
            initialDate: DateTime(2026, 9, 25), // Friday
            isStudent: true,
          ),
        ),
      ),
    );

    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('FRI'), findsOneWidget);
    expect(find.text('Friday'), findsWidgets);
    expect(find.text('Database Systems'), findsOneWidget);
    expect(find.text('BSIT 3-A'), findsWidgets);
  });

  testWidgets('ActualCalendarView switches selected date and shows classes for selected day', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActualCalendarView(
            schedules: sampleSchedules,
            initialDate: DateTime(2026, 9, 25), // Friday
            isTeacher: true,
          ),
        ),
      ),
    );

    // Initial Friday schedule is visible
    expect(find.text('Database Systems'), findsOneWidget);

    // Tap on a Monday date cell (e.g. 21 or 28)
    final mondayCell = find.text('21');
    expect(mondayCell, findsOneWidget);
    await tester.tap(mondayCell);
    await tester.pumpAndSettle();

    // Monday schedule should now be displayed
    expect(find.text('Software Engineering'), findsOneWidget);
    expect(find.text('Monday'), findsWidgets);
  });

  testWidgets('ActualCalendarView supports admin edit and delete callbacks', (tester) async {
    Map<String, dynamic>? editedSched;
    Map<String, dynamic>? deletedSched;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActualCalendarView(
            schedules: sampleSchedules,
            initialDate: DateTime(2026, 9, 25), // Friday
            isAdmin: true,
            onEditSchedule: (sched) => editedSched = sched,
            onDeleteSchedule: (sched) => deletedSched = sched,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(editedSched?['id'], equals('sched_2'));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(deletedSched?['id'], equals('sched_2'));
  });
}
