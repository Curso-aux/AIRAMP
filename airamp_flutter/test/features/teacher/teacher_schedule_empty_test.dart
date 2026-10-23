import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  final sampleTeacher = User(
    id: 'teacher_1',
    email: 'john.reyes@deped.gov.ph',
    fullName: 'Sir John Reyes',
    role: 'teacher',
  );

  final sampleSchedules = [
    {
      'id': 'sched_1',
      'subject_id': 101,
      'subject_name': 'General Mathematics',
      'section_name': 'STEM 12-A',
      'teacher_id': 'teacher_1',
      'teacher_name': 'Sir John Reyes',
      'day_of_week': 'Monday',
      'start_time': '08:00',
      'end_time': '09:30',
      'room': 'Room 302',
      'color_code': '#0D9488',
    },
    {
      'id': 'sched_2',
      'subject_id': 102,
      'subject_name': 'Earth & Life Science',
      'section_name': 'STEM 12-B',
      'teacher_id': 'teacher_1',
      'teacher_name': 'Sir John Reyes',
      'day_of_week': 'Monday',
      'start_time': '10:00',
      'end_time': '11:30',
      'room': 'Science Lab 1',
      'color_code': '#2563EB',
    },
  ];

  testWidgets('TeacherScheduleScreen when schedules are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherSchedulesProvider.overrideWith(() => MockEmptyScheduleNotifier()),
        ],
        child: const MaterialApp(
          home: TeacherScheduleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No Class Schedules Assigned'), findsOneWidget);
  });

  testWidgets('TeacherScheduleScreen renders Weekly Timetable Matrix like student with time column and positioned blocks', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
          teacherSchedulesProvider.overrideWith(() => MockScheduleNotifier(sampleSchedules)),
          teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
        ],
        child: const MaterialApp(
          home: TeacherScheduleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify matrix headers
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('TUE'), findsOneWidget);
    expect(find.text('WED'), findsOneWidget);
    expect(find.text('THU'), findsOneWidget);
    expect(find.text('FRI'), findsOneWidget);
    expect(find.text('SAT'), findsOneWidget);

    // Verify time slots in left column
    expect(find.text('7:00A'), findsOneWidget);
    expect(find.text('8:00A'), findsOneWidget);

    // Verify positioned period blocks
    expect(find.text('General Mathematics'), findsOneWidget);
    expect(find.text('Earth & Life Science'), findsOneWidget);
    expect(find.text('STEM 12-A'), findsOneWidget);
    expect(find.text('STEM 12-B'), findsOneWidget);
    expect(find.text('Room 302'), findsOneWidget);

    // Tap on General Mathematics period block to open Class Detail Modal
    await tester.tap(find.text('General Mathematics'));
    await tester.pumpAndSettle();

    // Verify modal contents
    expect(find.text('Handled Section'), findsOneWidget);
    expect(find.text('Schedule Time'), findsOneWidget);
    expect(find.text('Classroom'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Dismiss modal
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });
}

class MockAuthNotifier extends AuthNotifier {
  final User? _user;
  MockAuthNotifier(this._user);
  @override
  User? build() => _user;
}

class MockEmptyScheduleNotifier extends TeacherScheduleNotifier {
  @override
  List<Map<String, dynamic>> build() => [];
}

class MockScheduleNotifier extends TeacherScheduleNotifier {
  final List<Map<String, dynamic>> _schedules;
  MockScheduleNotifier(this._schedules);
  @override
  List<Map<String, dynamic>> build() => _schedules;
}
