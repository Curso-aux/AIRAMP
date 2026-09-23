import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../auth/application/auth_provider.dart';

/// Helper to get current weekday name ('Monday', 'Tuesday', etc.)
String getCurrentDayOfWeek() {
  final now = DateTime.now();
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[now.weekday - 1];
}

/// All schedules for the logged in teacher
final teacherSchedulesProvider = NotifierProvider<TeacherScheduleNotifier, List<Map<String, dynamic>>>(() {
  return TeacherScheduleNotifier();
});

class TeacherScheduleNotifier extends Notifier<List<Map<String, dynamic>>> {
  String? _filterDay;
  String? _filterSection;

  @override
  List<Map<String, dynamic>> build() {
    _load();
    return [];
  }

  String? _getTeacherId() {
    final user = ref.watch(authProvider);
    return user?.id;
  }

  Future<void> _load() async {
    final teacherId = _getTeacherId();
    if (teacherId == null) {
      if (ref.mounted) state = [];
      return;
    }
    final results = await DatabaseHelper().getClassSchedules(
      teacherId: teacherId,
      dayOfWeek: _filterDay,
      sectionName: _filterSection,
    );
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> filter({String? dayOfWeek, String? sectionName}) async {
    _filterDay = dayOfWeek;
    _filterSection = sectionName;
    await _load();
  }

  Future<void> reload() async => _load();

  /// Check conflict before saving
  Future<Map<String, dynamic>> checkConflict({
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    String? sectionName,
    String? room,
    String? excludeScheduleId,
  }) async {
    final teacherId = _getTeacherId();
    return await DatabaseHelper().checkScheduleConflict(
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      teacherId: teacherId,
      sectionName: sectionName,
      room: room,
      excludeScheduleId: excludeScheduleId,
    );
  }

  /// Create class schedule with automatic conflict detection
  Future<Map<String, dynamic>> addSchedule({
    required int subjectId,
    required String subjectName,
    required String sectionName,
    int? sectionId,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? colorCode,
  }) async {
    final teacher = ref.read(authProvider);
    if (teacher == null) throw StateError('No authenticated teacher');

    // Conflict check
    final conflictResult = await checkConflict(
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      sectionName: sectionName,
      room: room,
    );

    if (conflictResult['hasConflict'] == true) {
      return conflictResult;
    }

    await DatabaseHelper().createClassSchedule({
      'teacher_id': teacher.id,
      'teacher_name': teacher.fullName,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'section_id': sectionId,
      'section_name': sectionName,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'color_code': colorCode ?? '#0D9488',
      'school_id': teacher.schoolId ?? 'sch_main',
    });

    await _load();
    ref.invalidate(todayTeacherSchedulesProvider);
    ref.invalidate(sectionSchedulesProvider);
    ref.invalidate(allClassSchedulesProvider);
    ref.invalidate(scheduledSectionsProvider);
    return {'hasConflict': false};
  }

  /// Update existing schedule with conflict check
  Future<Map<String, dynamic>> updateSchedule({
    required String id,
    required int subjectId,
    required String subjectName,
    required String sectionName,
    int? sectionId,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? colorCode,
  }) async {
    final teacher = ref.read(authProvider);
    if (teacher == null) throw StateError('No authenticated teacher');

    final conflictResult = await checkConflict(
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      sectionName: sectionName,
      room: room,
      excludeScheduleId: id,
    );

    if (conflictResult['hasConflict'] == true) {
      return conflictResult;
    }

    await DatabaseHelper().updateClassSchedule(id, {
      'subject_id': subjectId,
      'subject_name': subjectName,
      'section_id': sectionId,
      'section_name': sectionName,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room,
      'color_code': colorCode ?? '#0D9488',
    });

    await _load();
    ref.invalidate(todayTeacherSchedulesProvider);
    ref.invalidate(sectionSchedulesProvider);
    ref.invalidate(allClassSchedulesProvider);
    ref.invalidate(scheduledSectionsProvider);
    return {'hasConflict': false};
  }

  /// Delete schedule
  Future<void> deleteSchedule(String id) async {
    await DatabaseHelper().deleteClassSchedule(id);
    await _load();
    ref.invalidate(todayTeacherSchedulesProvider);
    ref.invalidate(sectionSchedulesProvider);
    ref.invalidate(allClassSchedulesProvider);
    ref.invalidate(scheduledSectionsProvider);
  }
}

/// Today's schedules for current teacher
final todayTeacherSchedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(authProvider);
  final teacherId = user?.id;
  if (teacherId == null) return [];

  final today = getCurrentDayOfWeek();
  final list = await DatabaseHelper().getClassSchedules(
    teacherId: teacherId,
    dayOfWeek: today,
  );
  return list;
});

/// Schedules for a specific section (Used by student view and timetable)
final sectionSchedulesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, sectionName) async {
  if (sectionName.trim().isEmpty) return [];
  if (sectionName == 'All Sections') {
    return await DatabaseHelper().getClassSchedules();
  }
  return await DatabaseHelper().getClassSchedules(sectionName: sectionName.trim());
});

/// All class schedules across school (Used by student timetable and calendar view)
final allClassSchedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await DatabaseHelper().getClassSchedules();
});

/// Distinct section names that currently have uploaded schedules
final scheduledSectionsProvider = FutureProvider<List<String>>((ref) async {
  final all = await DatabaseHelper().getClassSchedules();
  final sections = all
      .map((s) => s['section_name'] as String?)
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();
  sections.sort();
  return sections;
});
