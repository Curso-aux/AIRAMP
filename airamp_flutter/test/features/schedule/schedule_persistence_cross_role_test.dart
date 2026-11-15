import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Requirement R3: Schedule Persistence and Cross-Role Synchronization', () {
    test('1. Schedule creation writes to SQLite and caches in SharedPreferences', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Clean slate
      await db.delete('class_schedules');

      final scheduleId = await helper.createClassSchedule({
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 101,
        'subject_name': 'General Mathematics',
        'section_id': 1,
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Monday',
        'start_time': '08:00 AM',
        'end_time': '09:30 AM',
        'room': 'Room 201',
        'color_code': '#0D9488',
      });

      expect(scheduleId, isNotEmpty);

      // Verify row exists in SQLite
      final rows = await db.query('class_schedules', where: 'id = ?', whereArgs: [scheduleId]);
      expect(rows, hasLength(1));
      expect(rows.first['subject_name'], 'General Mathematics');

      // Verify cache in SharedPreferences (local_cached_schedules_v1)
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('local_cached_schedules_v1');
      expect(cachedStr, isNotNull);
      final List<dynamic> cachedList = jsonDecode(cachedStr!);
      expect(cachedList.any((s) => s['id'] == scheduleId), isTrue);
    });

    test('2. Cross-Role Visibility: Schedule is visible to Master, Teacher, and Student', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;
      await db.delete('class_schedules');

      final schedId = await helper.createClassSchedule({
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 102,
        'subject_name': 'Science and Technology',
        'section_id': 1,
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Wednesday',
        'start_time': '10:00 AM',
        'end_time': '11:30 AM',
        'room': 'Science Lab',
        'color_code': '#2563EB',
      });

      // Master Timetable (no filter)
      final masterSchedules = await helper.getClassSchedules();
      expect(masterSchedules.any((s) => s['id'] == schedId), isTrue);

      // Teacher Schedule View (by teacher_id or teacher_name)
      final teacherById = await helper.getClassSchedules(teacherId: 'teacher_1');
      expect(teacherById.any((s) => s['id'] == schedId), isTrue);

      final teacherByName = await helper.getClassSchedules(teacherName: 'Sir John Reyes');
      expect(teacherByName.any((s) => s['id'] == schedId), isTrue);

      // Student Timetable View (by section_name exact and keyword)
      final studentExact = await helper.getClassSchedules(sectionName: 'Grade 10 - Emerald');
      expect(studentExact.any((s) => s['id'] == schedId), isTrue);

      final studentKeyword = await helper.getClassSchedules(sectionName: 'Emerald');
      expect(studentKeyword.any((s) => s['id'] == schedId), isTrue);
    });

    test('3. Destructive Startup Purge Removal: Schedules for Emerald, STEM B, and Gold persist', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Seed schedules for sections that used to be purged
      final emeraldId = await helper.createClassSchedule({
        'id': 'sched_emerald_math_1',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 101,
        'subject_name': 'Mathematics 10',
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Monday',
        'start_time': '08:00 AM',
        'end_time': '09:00 AM',
      });

      final stemId = await helper.createClassSchedule({
        'id': 'sched_stem_phys_1',
        'teacher_id': 'teacher_2',
        'teacher_name': 'Maam Santos',
        'subject_id': 103,
        'subject_name': 'General Physics 1',
        'section_name': 'Grade 11 - STEM B',
        'day_of_week': 'Tuesday',
        'start_time': '09:00 AM',
        'end_time': '10:00 AM',
      });

      final goldId = await helper.createClassSchedule({
        'id': 'sched_gold_eng_1',
        'teacher_id': 'teacher_3',
        'teacher_name': 'Sir Cruz',
        'subject_id': 104,
        'subject_name': 'English for Academic Purposes',
        'section_name': 'Grade 12 - Gold',
        'day_of_week': 'Thursday',
        'start_time': '11:00 AM',
        'end_time': '12:00 PM',
      });

      // Call _seedInitialData (simulating database open / application restart)
      await helper.seedInitialDataForTesting(db);

      // Assert that none of the schedules were purged
      final emeraldRows = await db.query('class_schedules', where: 'id = ?', whereArgs: [emeraldId]);
      expect(emeraldRows, hasLength(1), reason: 'Grade 10 - Emerald schedule must not be purged');

      final stemRows = await db.query('class_schedules', where: 'id = ?', whereArgs: [stemId]);
      expect(stemRows, hasLength(1), reason: 'Grade 11 - STEM B schedule must not be purged');

      final goldRows = await db.query('class_schedules', where: 'id = ?', whereArgs: [goldId]);
      expect(goldRows, hasLength(1), reason: 'Grade 12 - Gold schedule must not be purged');
    });

    test('4. Web In-Memory SQLite Wipe & Dual-Tier SharedPreferences Auto-Restore', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      // Ensure cache has a schedule
      await helper.createClassSchedule({
        'id': 'sched_persisted_test_99',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 201,
        'subject_name': 'Web Dev & Databases',
        'section_name': 'Grade 10 - Emerald',
        'day_of_week': 'Friday',
        'start_time': '01:00 PM',
        'end_time': '03:00 PM',
        'room': 'Computer Lab 2',
      });

      // Verify SharedPreferences has it
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('local_cached_schedules_v1'), contains('sched_persisted_test_99'));

      // Simulate Web browser reload / SQLite in-memory reset:
      // Clear SQLite table directly WITHOUT deleting SharedPreferences cache
      await db.delete('class_schedules');
      final wipedCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM class_schedules')) ?? 0;
      expect(wipedCount, 0);

      // Now query schedules via getClassSchedules(): it should auto-restore from SharedPreferences!
      final restoredSchedules = await helper.getClassSchedules();
      expect(restoredSchedules.any((s) => s['id'] == 'sched_persisted_test_99'), isTrue);

      // And it should immediately be visible to Teacher and Student views as well
      final teacherSchedules = await helper.getClassSchedules(teacherId: 'teacher_1');
      expect(teacherSchedules.any((s) => s['id'] == 'sched_persisted_test_99'), isTrue);

      final studentSchedules = await helper.getClassSchedules(sectionName: 'Grade 10 - Emerald');
      expect(studentSchedules.any((s) => s['id'] == 'sched_persisted_test_99'), isTrue);
    });

    test('5. Update and delete mutations persist in both SQLite and SharedPreferences cache', () async {
      final helper = DatabaseHelper();
      final db = await helper.database;

      final schedId = await helper.createClassSchedule({
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'subject_id': 301,
        'subject_name': 'RoboticsNC',
        'section_name': 'Grade 11 - STEM B',
        'day_of_week': 'Monday',
        'start_time': '08:00 AM',
        'end_time': '09:00 AM',
        'room': 'Room 101',
      });

      // Update room and subject name
      await helper.updateClassSchedule(schedId, {
        'room': 'Advanced Robotics Hub',
        'subject_name': 'Robotics NC II Specialized',
      });

      // Verify SQLite has updated data
      var rows = await db.query('class_schedules', where: 'id = ?', whereArgs: [schedId]);
      expect(rows.first['room'], 'Advanced Robotics Hub');
      expect(rows.first['subject_name'], 'Robotics NC II Specialized');

      // Verify SharedPreferences cache has updated data
      var prefs = await SharedPreferences.getInstance();
      var cachedStr = prefs.getString('local_cached_schedules_v1')!;
      expect(cachedStr, contains('Advanced Robotics Hub'));
      expect(cachedStr, contains('Robotics NC II Specialized'));

      // Delete the schedule
      await helper.deleteClassSchedule(schedId);

      // Verify SQLite no longer has the row
      rows = await db.query('class_schedules', where: 'id = ?', whereArgs: [schedId]);
      expect(rows, isEmpty);

      // Verify SharedPreferences cache no longer has the row
      prefs = await SharedPreferences.getInstance();
      cachedStr = prefs.getString('local_cached_schedules_v1')!;
      expect(cachedStr.contains(schedId), isFalse);
    });
  });
}
