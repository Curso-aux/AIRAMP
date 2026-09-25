import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/student/presentation/components/student_schedule_widget.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DatabaseHelper correctly queries schedule for Grade 10 - Emerald and Emerald', () async {
    final helper = DatabaseHelper();
    await helper.database;

    // Insert schedule for Grade 10 - Emerald
    await helper.createClassSchedule({
      'id': 'test_sched_emerald_1',
      'teacher_id': 'teacher_1',
      'teacher_name': 'Sir John Reyes',
      'subject_id': 1,
      'subject_name': 'CSS NC II - Computer Systems Servicing',
      'section_name': 'Grade 10 - Emerald',
      'day_of_week': 'Tuesday',
      'start_time': '08:00',
      'end_time': '09:30',
      'room': 'Lab 1',
      'color_code': '#E11D48',
    });

    // 1. Query with exact sectionName 'Grade 10 - Emerald'
    final schedulesFull = await helper.getClassSchedules(sectionName: 'Grade 10 - Emerald');
    expect(schedulesFull.any((s) => s['subject_name'] == 'CSS NC II - Computer Systems Servicing'), isTrue);

    // 2. Query with 'Emerald'
    final schedulesShort = await helper.getClassSchedules(sectionName: 'Emerald');
    expect(schedulesShort.any((s) => s['subject_name'] == 'CSS NC II - Computer Systems Servicing'), isTrue);

    // 3. Query with en-dash 'Grade 10 – Emerald'
    final schedulesEnDash = await helper.getClassSchedules(sectionName: 'Grade 10 \u2013 Emerald');
    expect(schedulesEnDash.any((s) => s['subject_name'] == 'CSS NC II - Computer Systems Servicing'), isTrue);
  });

  testWidgets('WeeklyTimetableDialog displays schedules when provided', (tester) async {
    final sampleScheds = [
      {
        'id': 'test_sched_emerald_1',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 1,
        'subject_name': 'CSS NC II - Computer Systems Servicing',
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Tuesday',
        'start_time': '08:00',
        'end_time': '09:30',
        'room': 'Lab 1',
        'color_code': '#E11D48',
      }
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sectionSchedulesProvider('Grade 10 - Emerald').overrideWith((ref) async => sampleScheds),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WeeklyTimetableDialog(sectionName: 'Grade 10 - Emerald'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it does NOT show empty state
    expect(find.text('No Classes Scheduled for Section Grade 10 - Emerald'), findsNothing);
    // Verify CSS NC II is rendered
    expect(find.text('CSS NC II - Computer Systems Servicing'), findsWidgets);
  });
}
