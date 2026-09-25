import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/teacher_schedule_screen.dart';
import 'package:airamp_flutter/src/features/teacher/presentation/components/halftone_pattern.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_repository.dart';
import 'package:airamp_flutter/src/features/teacher/data/teacher_schedule_repository.dart';
import 'package:airamp_flutter/src/features/admin/presentation/web/admin_web_schedule_screen.dart';
import 'package:airamp_flutter/src/features/admin/data/admin_repository.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

class MockAuthNotifier extends AuthNotifier {
  final User? _user;
  MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

class _FakeTeacherScheduleNotifier extends TeacherScheduleNotifier {
  final List<Map<String, dynamic>> schedules;
  _FakeTeacherScheduleNotifier(this.schedules);

  @override
  List<Map<String, dynamic>> build() => schedules;
}

class _FakeAdminTeachersNotifier extends AdminTeachersNotifier {
  final List<Map<String, dynamic>> teachers;
  _FakeAdminTeachersNotifier(this.teachers);

  @override
  List<Map<String, dynamic>> build() => teachers;

  @override
  Future<void> loadTeachers() async {}
}

class _FakeSectionsNotifier extends SectionsNotifier {
  final List<Map<String, dynamic>> sections;
  _FakeSectionsNotifier(this.sections);

  @override
  List<Map<String, dynamic>> build() => sections;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final sampleTeacher = User(
    id: 'teacher_1',
    email: 'teacher@school.edu',
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

  group('Halftone Pattern & Teacher Schedule Read-Only Tests', () {
    testWidgets('1. TeacherScheduleScreen renders HalftoneCardDecoration and removes AI-slop left line', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherSchedulesProvider.overrideWith(() => _FakeTeacherScheduleNotifier(sampleSchedules)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
          ],
          child: const MaterialApp(
            home: TeacherScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // HalftoneCardDecoration should be present for the schedule cards
      expect(find.byType(HalftoneCardDecoration), findsWidgets);

      // Verify subject names and section pills are rendered
      expect(find.text('General Mathematics'), findsOneWidget);
      expect(find.text('Earth & Life Science'), findsOneWidget);
      expect(find.text('STEM 12-A'), findsOneWidget);
      expect(find.text('STEM 12-B'), findsOneWidget);
    });

    testWidgets('2. Teacher schedule is read-only: no "+ Schedule Class", no day add button, and no card edit/delete buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => MockAuthNotifier(sampleTeacher)),
            teacherSchedulesProvider.overrideWith(() => _FakeTeacherScheduleNotifier(sampleSchedules)),
            teacherHandledSectionsProvider.overrideWith((ref) async => ['STEM 12-A', 'STEM 12-B']),
          ],
          child: const MaterialApp(
            home: TeacherScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "+ Schedule Class" button should NOT exist in teacher screen
      expect(find.text('Schedule Class'), findsNothing);
      expect(find.text('Schedule Class Now'), findsNothing);

      // Day add circle button should NOT exist
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);

      // 3-dots popup menu button for edit/delete should NOT exist
      expect(find.byIcon(Icons.more_vert), findsNothing);

      // Admin Assigned badge indicator should be displayed
      expect(find.text('Admin Assigned'), findsOneWidget);
      expect(find.text('Assigned'), findsWidgets);
    });

    testWidgets('3. HalftoneWavePainter draws circles without exceptions', (tester) async {
      final painter = HalftoneWavePainter(
        color: const Color(0xFF0D9488),
        dotSpacing: 8.0,
        maxRadius: 3.5,
        baseOpacity: 0.25,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(200, 100);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('Admin Schedule Management Screen Tests', () {
    testWidgets('4. AdminWebScheduleScreen provides assign schedule action and filters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allClassSchedulesProvider.overrideWith((ref) async => sampleSchedules),
            adminTeachersProvider.overrideWith(() => _FakeAdminTeachersNotifier([
                  {'id': 'teacher_1', 'full_name': 'Sir John Reyes', 'email': 'teacher@school.edu'}
                ])),
            sectionsProvider.overrideWith(() => _FakeSectionsNotifier([
                  {'id': 1, 'name': 'STEM 12-A'},
                  {'id': 2, 'name': 'STEM 12-B'},
                ])),
          ],
          child: const MaterialApp(
            home: AdminWebScheduleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Master Timetable title
      expect(find.text('Master Timetable & Class Schedules'), findsOneWidget);

      // Admin has the "Assign Class Schedule" button
      expect(find.text('Assign Class Schedule'), findsOneWidget);

      // Both classes are rendered with halftone decoration
      expect(find.text('General Mathematics'), findsOneWidget);
      expect(find.text('Earth & Life Science'), findsOneWidget);
      expect(find.byType(HalftoneCardDecoration), findsWidgets);

      // Admin has the action menu (Icons.more_vert) to edit/delete
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });
  });
}
